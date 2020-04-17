#!/bin/sh

echo "Downloading grub..."
pacman --noconfirm -S grub efibootmgr >/dev/null 2>&1
grub-install &&
grub-mkconfig -o /boot/grub/grub.cfg

