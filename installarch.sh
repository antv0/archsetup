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

error(){
	echo "$1"; exit
}

if [ "$use_paclan" = true ]; then mount -o remount,size=2G /run/archiso/cowspace || error "not enough ram. Please disable use_paclan"; fi
ping -c 1 archlinux.org || error "check your internet connexion."

mountpoint -q /mnt || error "Nothing is mounted on /mnt."

#update the mirrors with reflector in installation environment
if [ "$use_reflector" = true ]; then
	pacman -Sy --noconfirm --needed reflector
	reflector -c $country --score 5 --save /etc/pacman.d/mirrorlist
fi

if [ "$use_paclan" = true ]; then
	useradd -m -g wheel aur &&
	echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers &&
	pacman -Sy --noconfirm --needed base-devel git &&
	cd /tmp && rm -rf /tmp/paclan &&
	sudo -u aur git clone https://aur.archlinux.org/paclan.git &&
	cd paclan &&
	sudo -u aur makepkg -si --noconfirm || error "error while installing paclan."
fi

pacstrap /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab


ln -sf /mnt/usr/share/zoneinfo/$timezone /mnt/etc/localtime
$chroot hwclock --systohc
sed -i "s/#$locale/$locale/g" /mnt/etc/locale.gen
$chroot locale-gen
echo "LANG=$LANG" > /mnt/etc/locale.conf
echo "KEYMAP=$keymap" > /mnt/etc/vconsole.conf
echo $hostname > /mnt/etc/hostname
echo "127.0.0.1	localhost
::1		localhost
127.0.1.1	"$hostname".localdomain	"$hostname > /mnt/etc/hosts
$chroot mkinitcpio -P

if [ -z $root_password ]; then $chroot passwd;
else echo $root_password | $chroot passwd --stdin; fi
unset root_password

#update the mirrors with reflector
if [ "$use_reflector" = true ]; then
	$chroot pacman -Sy --noconfirm --needed reflector
	$chroot reflector -c $country --score 5 --save /etc/pacman.d/mirrorlist
fi

cd /mnt/root
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/postinstall.sh
chmod 777 postinstall.sh
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/installgrub.sh
chmod 777 installgrub.sh
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/packages.csv

arch-chroot /mnt
