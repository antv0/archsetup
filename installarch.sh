#!/bin/sh

#mount your drive in /mnt before running this script

hostname="arch"
country="france" #for reflector
timezone="Europe/Paris"
locale="fr_FR.UTF-8"
lang="fr_FR.UTF8"
keymap="fr-pc"
chroot="arch-chroot /mnt "
use_paclan=true
use_reflector=true
root_password=""

message() {
	echo -e "\033[36m[installarch.sh]\033[0m $1"
}

error(){
	echo -e "\033[31m$1\033[0m"; exit
}

if [ "$use_paclan" = true ]; then mount -o remount,size=2G /run/archiso/cowspace || error "not enough ram. Please disable use_paclan"; fi
ping -c 1 archlinux.org >/dev/null 2>&1 || error "check your internet connexion."

mountpoint -q /mnt || error "Nothing is mounted on /mnt."

#update the mirrors with reflector in installation environment
if [ "$use_reflector" = true ]; then
	message "Installing reflector in installation environment..."
	pacman -Sy --noconfirm --needed reflector >/dev/null 2>&1
	reflector -c $country --score 5 --save /etc/pacman.d/mirrorlist >/dev/null 2>&1
fi

if [ "$use_paclan" = true ]; then
	message "Installing paclan in installation environment..."
	useradd -m -g wheel aur >/dev/null 2>&1 &&
	echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers &&
	pacman -Sy --noconfirm --needed base-devel git >/dev/null 2>&1 &&
	cd /tmp && rm -rf /tmp/paclan >/dev/null 2>&1 &&
	sudo -u aur git clone https://aur.archlinux.org/paclan.git >/dev/null 2>&1 &&
	cd paclan >/dev/null 2>&1 &&
	sudo -u aur makepkg -si --noconfirm >/dev/null 2>&1 || error "error while installing paclan."
    sed -i "s/\[extra\]/\[extra\]\nInclude = \/etc\/pacman.d\/mirrorlist\.paclan/g" /etc/pacman.conf
    sed -i "s/\[core\]/\[core\]\nInclude = \/etc\/pacman.d\/mirrorlist\.paclan/g" /etc/pacman.conf
    sed -i "s/\[community\]/\[community\]\nInclude = \/etc\/pacman.d\/mirrorlist\.paclan/g" /etc/pacman.conf
fi

message "running pacstrap..."
pacstrap /mnt base linux linux-firmware

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
message "Updating mirrors with reflector."
if [ "$use_reflector" = true ]; then
	$chroot pacman -Sy --noconfirm --needed reflector >/dev/null 2>&1
	$chroot reflector -c $country --score 5 --save /etc/pacman.d/mirrorlist
fi

message "Downloading other installation scripts in /root."
cd /mnt/root
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/postinstall.sh >/dev/null 2>&1
chmod 777 postinstall.sh
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/grub-install-efi.sh >/dev/null 2>&1
chmod 777 grub-install-efi.sh
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/grub-install-mbr.sh >/dev/null 2>&1
chmod 777 grub-install-mbr.sh
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/packages.csv >/dev/null 2>&1

message "Chroot into new system."
$chroot 'bash --rcfile <<< "cd /root"'
