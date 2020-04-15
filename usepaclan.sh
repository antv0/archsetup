#!/bin/sh

git clone https://aur.archlinux.org/paclan.git || exit
cd paclan || exit
makepkg -si
