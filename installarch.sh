#!/bin/sh

#mount your drive in /mnt before running this script

hostname="arch"
country="france" #for reflector
timezone="Europe/Paris"
locale="fr_FR.UTF-8"
lang="fr_FR.UTF8"
keymap="fr-pc"
chroot="arch-chroot /mnt "
additional_packages="https://raw.githubusercontent.com/antv0/archsetup/master/packages.txt"
use_reflector=false
root_password=""
users=()
passwords=()
dotfiles=("https://github.com/antv0/dotfiles")

message() {
	echo -e "\033[36m[installarch.sh]\033[0m $1"
}

error(){
	echo -e "\033[31m$1\033[0m"; exit
}

pkg() { # print the list of packages in $1 section
    curl -s -f $additional_packages | sed 's/#.*$//g;/^$/d' $file | awk -v field=$1 'BEGIN {ok=0;s=""} /.*:$/ {ok = 0} { re="^" field ":$"; if ($0 ~ re) { ok=1 } else { if(ok) { print $0} } }' | tr '\n' ' ' | tr -s ' '
}

ping -c 1 archlinux.org >/dev/null 2>&1 || error "check your internet connexion."

mountpoint -q /mnt || error "Nothing is mounted on /mnt."

#update the mirrors with reflector in installation environment
if [ "$use_reflector" = true ]; then
	message "Installing reflector in installation environment..."
	pacman -Sy --noconfirm --needed reflector >/dev/null 2>&1
	reflector -c $country --score 5 --save /etc/pacman.d/mirrorlist >/dev/null 2>&1
fi

# if [ -z users ]; then
    # message "No user will be created. Continue ? [y/N]"
    # read yn
    # case $yn in
        # [Yy]* ) break;;
        # [Nn]*|'' ) exit;;
        # * ) echo "Please answer.";;
    # esac
# fi

# check if usernames are valid
for user in "${users[@]}"
do
   echo "$user" | grep "^[a-z_][a-z0-9_-]*$" || error "invalid username : \"$user\""
done

message "running pacstrap..."
pacstrap -c /mnt base linux linux-firmware

message "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

message "Setting up timezone, language, keymap, hostname..."
$chroot ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
$chroot hwclock --systohc >/dev/null 2>&1
sed -i "s/#$locale/$locale/g" /mnt/etc/locale.gen
$chroot locale-gen >/dev/null 2>&1
echo "LANG=$lang" > /mnt/etc/locale.conf
echo "KEYMAP=$keymap" > /mnt/etc/vconsole.conf
echo $hostname > /mnt/etc/hostname
echo "127.0.0.1	localhost
::1		localhost
127.0.1.1	"$hostname".localdomain	"$hostname > /mnt/etc/hosts
message "running mkinicpio -P..."
$chroot mkinitcpio -P >/dev/null 2>&1

message "Setting root password."
if [ -z $root_password ]; then $chroot passwd;
else echo $root_password | $chroot passwd --stdin; fi
unset root_password

#update the mirrors with reflector
if [ "$use_reflector" = true ]; then
    message "Updating mirrors with reflector."
	$chroot pacman -Sy --noconfirm --needed reflector >/dev/null 2>&1
	$chroot reflector -c $country --score 5 --save /etc/pacman.d/mirrorlist
fi

# add users

for user in "${users[@]}"
do
    $chroot useradd -m -g wheel -s /bin/zsh "$user" >/dev/null 2>&1 || error "Error while adding user"
done

# set passwords
for n in $( eval echo {0..$((${#ar[@]}-1))})
do
    [ -z ${users[n]} ] || echo ${passwords[n]} | $chroot passwd ${users[n]} --stdin
done
unset passwords

message "Installing doas, curl, base-devel, git..."
pacstrap -c /mnt opendoas curl base-devel git
echo "permit nopass :wheel as root" > /mnt/etc/doas.conf

# Make pacman and yay colorful.
sed -i "s/^#Color/Color/" /mnt/etc/pacman.conf

# Use all cores for compilation.
# sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /mnt/etc/makepkg.conf

# installing packages
# arch repo:
pacstrap -c /mnt $(pkg arch)

#aur
if [ -z $users ]; then
    message "you need at least one user to install anything from aur. Skiping yay and aur packages..."
else
    # Install yay
    message "Installing yay..."
    dir=/mnt/tmp/aur/yay
    mkdir -p $dir
    cd $dir
    $chroot -u "${users[0]}" git clone https://aur.archlinux.org/yay.git >/dev/null 2>&1 || error "Error while downloading yay."
    cd yay
    $chroot -u "${users[0]}" makepkg -si --noconfirm  >/dev/null 2>&1 || error "Error while installing yay."
    cd ~;

    $chroot -u "${users[0]}" yay -S --noconfirm $(pkg aur)

    #git
    for $name in $(pkg git)
    do
        bn=$(basename "$name" .git)
        dir=/mnt/tmp/git/$bn
        $chroot -u "${users[0]}" git clone "$name" "$dir"
        cd "$dir" || exit
        $chroot -u "${users[0]}" makepkg -si
    done
fi

# Install the dotfiles in the user's home directory
for n in $( eval echo {0..$((${#ar[@]}-1))})
do
    message "Installing dotfiles..."
    dir=/mnt/tmp/dotfiles
    # [ ! -d "/home/$name" ] && mkdir -p /home/$name
    chown -R "${users[n]}":wheel "$dir"
    $chroot -u "${users[n]}" git clone --depth 1 ${dotfiles[n]} "$dir"
    $chroot -u "${users[n]}" cp -rfT "$dir" /home/${users[n]}
    rm -f "/home/${users[n]}/README.md" "/home/${users[n]}/LICENSE"
done

# Enable the network manager
message "Enabling NetworkManager..."
$chroot systemctl enable NetworkManager.service >/dev/null 2>&1

# Enable the auto time synchronisation.
message "Enabling systemd-timesyncd..."
$chroot systemctl enable systemd-timesyncd.service >/dev/null 2>&1

# Most important commands! Get rid of the beep!
message "Get rid of the beep!"
$chroot rmmod pcspkr
echo "blacklist pcspkr" > /mnt/etc/modprobe.d/nobeep.conf

# message "Downloading other installation scripts in /root."
# cd /mnt/root
# curl -O https://raw.githubusercontent.com/antv0/archsetup/master/postinstall.sh >/dev/null 2>&1
# chmod 777 postinstall.sh
# curl -O https://raw.githubusercontent.com/antv0/archsetup/master/grub-install-efi.sh >/dev/null 2>&1
# chmod 777 grub-install-efi.sh
# curl -O https://raw.githubusercontent.com/antv0/archsetup/master/grub-install-mbr.sh >/dev/null 2>&1
# chmod 777 grub-install-mbr.sh
# curl -O https://raw.githubusercontent.com/antv0/archsetup/master/packages.csv >/dev/null 2>&1

message "Installation completed."

# message "Chroot into new system."
# $chroot
