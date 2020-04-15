#!/bin/bash

pacman --noconfirm -S pacredir
systemctl enable pacserve.service pacredir.service

perl -i -0pe 's/\nInclude = \/etc\/pacman.d\/mirrorlist/\nInclude = \/etc\/pacman.d\/pacredir\nInclude = \/etc\/pacman.d\/mirrorlist/g' /etc/pacman.conf
perl -i -0pe 's/\nInclude = \/etc\/pacman.d\/pacredir\nInclude = \/etc\/pacman.d\/pacredir/\nInclude = \/etc\/pacman.d\/pacredir/g' /etc/pacman.conf
