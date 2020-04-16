#!/bin/sh

pacman --noconfirm -S grub efibootmgr
grub-install
grub-mkconfig -o /boot/grub/grub.cfg

