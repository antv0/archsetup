#!/bin/sh

#mount your drive in /mnt before running this script

hostname="arch"
country="france"
timezone="Europe/Paris"

ping -c 5 archlinux.org || (echo "check your internet connexion."; exit)

#update the mirrors with reflector in installation environment
pacman -noconfirm -S reflector
reflector -c $country -l 5 --sort rate --save /etc/pacman.d/mirrorlist

pacstrap /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt

ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
hwclock --systohc
sed -i "s/#fr_FR.UTF-8/fr_FR.UTF-8/g" /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF8" > /etc/locale.conf
echo "KEYMAP=fr-pc" > /etc/vconsole.conf
echo $hostname > /etc/hostname
echo "127.0.0.1	localhost
::1		localhost
127.0.1.1	"$hostname".localdomain	"$hostname > /etc/hosts
mkinitcpio -P
passwd

#update the mirrors with reflector
pacman -noconfirm -S reflector
reflector -c $country -l 5 --sort rate --save /etc/pacman.d/mirrorlist

cd ~
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/postinstall.sh
chmod +x postinstall.sh
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/installgrub.sh
chmod +x installgrub.sh
curl -O https://raw.githubusercontent.com/antv0/archsetup/master/packages.csv
