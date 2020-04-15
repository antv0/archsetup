#!/bin/sh

#mount your drive in /mnt before running this script

hostname="arch"
country="france"
timezone="Europe/Paris"
chroot="arch-chroot /mnt "
usepaclan=true

error(){
	echo "$1"; exit
}

if [ "$usepaclan" = true ]; then mount -o remount,size=1G /run/archiso/cowspace || error "not enough ram. Please disable usepaclan"; fi
ping -c 1 archlinux.org || error "check your internet connexion."

mountpoint -q /mnt || error "Nothing is mounted on /mnt."

#update the mirrors with reflector in installation environment
pacman -Sy --noconfirm --needed reflector
reflector -c $country --score 5 --save /etc/pacman.d/mirrorlist

if [ "$usepaclan" = true ]; then
	pacman -Sy --noconfirm --needed base-devel &&
	cd /tmp && rm -rf /tmp/paclan &&
	sudo -u nobody git clone https://aur.archlinux.org/paclan.git &&
	cd paclan &&
	sudo -u makepkg -si
fi

pacstrap /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab


ln -sf /mnt/usr/share/zoneinfo/$timezone /mnt/etc/localtime
$chroot hwclock --systohc
sed -i "s/#fr_FR.UTF-8/fr_FR.UTF-8/g" /mnt/etc/locale.gen
$chroot locale-gen
echo "LANG=fr_FR.UTF8" > /mnt/etc/locale.conf
echo "KEYMAP=fr-pc" > /mnt/etc/vconsole.conf
echo $hostname > /mnt/etc/hostname
echo "127.0.0.1	localhost
::1		localhost
127.0.1.1	"$hostname".localdomain	"$hostname > /mnt/etc/hosts
$chroot mkinitcpio -P
$chroot passwd

#update the mirrors with reflector
$chroot pacman -Sy --noconfirm --needed reflector
$chroot reflector -c $country --score 5 --save /etc/pacman.d/mirrorlist

cd /mnt/root
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/postinstall.sh
chmod 777 postinstall.sh
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/installgrub.sh
chmod 777 installgrub.sh
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/packages.csv
