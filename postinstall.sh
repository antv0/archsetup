#!/bin/sh

name="" #username
pass1="" #user password
dotfiles_repository="https://github.com/antv0/dotfiles"
packages_list="packages.csv"
git_dir="$working_dir/git"

###########
#FUNCTIONS#
###########

message() {
	echo -e "\033[36m[postinstall.sh]\033[0m $1"
}

error(){
	echo -e "\033[31m$1\033[0m"; exit
}

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

setperm() { # Set special sudoers settings.
	echo "%wheel ALL=(ALL) NOPASSWD: ALL #CUSTOM" >> /etc/sudoers
}





########
#SCRIPT#
########

#check root user
if [[ $EUID -ne 0 ]]; then error "You must run this with superuser privileges."; fi

#check if $packages_list file exist
if ! [ -f "$packages_list" ]; then error "'package_list' file not available."; exit; fi

# Get and verify username and password.
# Prompts user for new username an password.
if [ -z $name ]; then
	message "Enter a name for the user account : "
	read name
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		message "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _."
		read name
	done
fi

if [ -z $pass1 ]; then
	message "Enter a password for that user:"
	read -s pass1
	message "Retype password."
	read -s pass2
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		message "Passwords do not match.\\n\\nEnter password again."
		read -s pass1
		message "Retype password."
		read -s pass2
	done
fi

# Add user
useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 || error "Error while adding user"
usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
echo "$name:$pass1" | chpasswd
unset pass1 pass2

# Refresh Arch keyring
message "Refreshing Arch keyring..."
pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1

message "Installing curl, base-devel, git..."
install_pacman curl
install_pacman base-devel
install_pacman git

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
setperm

# Make pacman and yay colorful and adds eye candy on the progress bar because why not.
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color/Color/" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

# Install yay
[ -f "/usr/bin/yay" ] || (
message "Installing yay..."
dir=$(sudo -u "$name" mktemp -d)
cd $dir
sudo -u "$name" git clone https://aur.archlinux.org/yay.git >/dev/null 2>&1 || error "Error while downloading yay."
cd yay
sudo -u "$name" makepkg -si --noconfirm  >/dev/null 2>&1 || error "Error while installing yay."
cd ~);

# Create the directory where the git packages are downloaded
git_dir="/home/$name/git"
mkdir -p "$git_dir"; chown -R "$name":wheel "$git_dir"
message "Git packages will be downloaded in $git_dir."

# Install all the packages
message "Installing the packages"
sed '/^#/d' $packages_list > /tmp/packages.csv
total=$(wc -l < /tmp/packages.csv)
aurinstalled=$(pacman -Qqm)
while IFS=, read -r tag program comment; do
	n=$((n+1))
	message "==> [$n/$total] $program"
	case "$tag" in
		"A") install_yay	"$program" ;;
		"G") install_git    "$program" ;;
		  *) install_pacman "$program" ;;
	esac
done < /tmp/packages.csv

# Install the dotfiles in the user's home directory
message "Installing dotfiles..."
dir=$(mktemp -d)
[ ! -d "/home/$name" ] && mkdir -p /home/$name
chown -R "$name":wheel "$dir" /home/$name
sudo -u "$name" git clone --depth 1 $dotfiles_repository "$dir" >/dev/null 2>&1
sudo -u "$name" cp -rfT "$dir" /home/$name
rm -f "/home/$name/README.md" "/home/$name/LICENSE"

# Enable the network manager
message "Enabling NetworkManager..."
systemctl enable NetworkManager.service >/dev/null 2>&1

# Enable the auto time synchronisation.
message "Enabling systemd-timesyncd..."
systemctl enable systemd-timesyncd.service >/dev/null 2>&1

# Most important commands! Get rid of the beep!
message "Get rid of the beep!"
rmmod pcspkr
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

# Make zsh the default shell for the user.
message "Set zsh as default shell for $name."
chsh -s /usr/bin/zsh $name >/dev/null 2>&1

# Remove special permissions
rmperms

# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
message "Allowing $name to run serveral important commands such as shutdown, reboot, updating, etc. without a password."
echo \
"%wheel ALL=(ALL) ALL
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/systemctl restart NetworkManager,/usr/bin/loadkeys,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/pacman -Syyuw --noconfirm" > /etc/sudoers.d/nopassword
chmod 0440 /etc/sudoers.d/nopassword

message "Installation completed."
