#!/bin/sh

dotfiles_repository="https://github.com/antv0/dotfiles"
aurhelper="yay"
packages_list="packages.csv"
git_dir="$working_dir/git"
name=""

###########
#FUNCTIONS#
###########

install_pacman(){ 
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

install_git() {
	progname="$(basename "$1" .git)"
	dir="$git_dir/$progname"
	sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
}

install_yay() {
	sudo -u "$name" yay -S --noconfirm "$1" >/dev/null 2>&1
}

rmperms() {
	sed -i "/#CUSTOM/d" /etc/sudoers
}

newperm() { # Set special sudoers settings for install (or after).
	echo "$1 #CUSTOM" >> /etc/sudoers ;}





########
#SCRIPT#
########

#check root user
if [[ $EUID -ne 0 ]]; then
  echo "You must run this with superuser privileges." 2>&1
  exit 1
fi

#check if $packages_list file exist
if ! [ -f "$packages_list" ]; then echo "ERROR : package_list file not available."; exit; fi

# Get and verify username and password.
# Prompts user for new username an password.
echo "Enter a name for the user account : "
read name
while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
	echo "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _."
	read name
done
echo "Enter a password for that user:"
read -s pass1
echo "Retype password."
read -s pass2
while ! [ "$pass1" = "$pass2" ]; do
	unset pass2
	echo "Passwords do not match.\\n\\nEnter password again."
	read -s pass1
	echo "Retype password."
	read -s pass2
done

# Add user
useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1
usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
echo "$name:$pass1" | chpasswd
unset pass1 pass2

# Refresh Arch keyring
echo "refreshing Arch keyring..."
pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1

echo "Installing curl, base-devel, git..."
install_pacman curl
install_pacman base-devel
install_pacman git

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman and yay colorful and adds eye candy on the progress bar because why not.
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color/Color/" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

# Install yay
[ -f "/usr/bin/yay" ] || (
echo "Installing yay..."
dir=$(sudo -u "$name" mktemp -d)
cd $dir
sudo -u "$name" git clone https://aur.archlinux.org/yay.git >/dev/null 2>&1
cd yay
sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
cd ~);

# Create the directory where the git packages are downloaded
git_dir="/home/$name/git"
mkdir -p "$git_dir"; chown -R "$name":wheel "$git_dir"

# Install all the packages
sed '/^#/d' $packages_list > /tmp/progs.csv
total=$(wc -l < $packages_list)
aurinstalled=$(pacman -Qqm)
while IFS=, read -r tag program comment; do
	n=$((n+1))
	echo -e "\033[1m==> [$n/$total]\033[0m \033[4m$program"
	case "$tag" in
		"A") install_yay	"$program" ;;
		"G") install_git    "$program" ;;
		  *) install_pacman "$program" ;;
	esac
done < /tmp/progs.csv

# Install the dotfiles in the user's home directory
dir=$(mktemp -d)
[ ! -d "/home/$name" ] && mkdir -p /home/$name
chown -R "$name":wheel "$dir" /home/$name
sudo -u "$name" git clone --depth 1 $dotfiles_repository "$dir" >/dev/null 2>&1
sudo -u "$name" cp -rfT "$dir" /home/$name
rm -f "/home/$name/README.md" "/home/$name/LICENSE"

# Enable the auto time synchronisation.
systemctl enable systemd-timesyncd.service

# Most important commands! Get rid of the beep!
rmmod pcspkr
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

# Make zsh the default shell for the user.
chsh -s /usr/bin/zsh $name

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
rmperms
newperm "%wheel ALL=(ALL) ALL"
newperm "%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/systemctl restart NetworkManager,/usr/bin/loadkeys,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/pacman -Syyuw --noconfirm"

echo "==> Installation completed."
