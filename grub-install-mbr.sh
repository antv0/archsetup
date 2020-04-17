#!/bin/sh

if [ -z $1 ]; then
	echo "Install device isn't specified. (ex: './grub-install-mbr.sh /dev/sda')"
	exit
fi

echo "Downloading grub..."
pacman -S --noconfirm --needed grub >/dev/null 2>&1
grub-install $1 &&
grub-mkconfig -o /boot/grub/grub.cfg

