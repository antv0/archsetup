#!/bin/sh

pacman -S --noconfirm --needed grub
grub-install $1
grub-mkconfig -o /boot/grub/grub.cfg

