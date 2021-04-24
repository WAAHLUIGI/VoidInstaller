#!/bin/sh


#fetch the rootfs tarball, the sha256sums and the signatures

wget https://alpha.de.repo.voidlinux.org/live/current/void-x86_64-ROOTFS-20210218.tar.xz
wget https://alpha.de.repo.voidlinux.org/live/current/sha256sum.sig
wget https://alpha.de.repo.voidlinux.org/live/current/sha256sum.txt
wget https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/void-release-keys/files/void-release-20210218.pub


# Verify the image for security


signify -C -p void-release-20210218.pub -x sha256sum.sig void-x86_64-ROOTFS-20210218.tar.xz
sha256sum -c --ignore-missing sha256sum.txt

echo "What partition do you want to install Void on? \c"
read PARTITION


mkdir voidinstall				# make a new directory and mount it under it, since /mnt
mount $PARTITION ./voidinstall/			# could already have something mounted on it
rm -rf voidinstall/*
tar xvf void-x86_64-ROOTFS-20210218.tar.xz -C voidinstall
mount --rbind /sys voidinstall/sys && mount --make-rslave voidinstall/sys
mount --rbind /dev voidinstall/dev && mount --make-rslave voidinstall/dev
mount --rbind /proc voidinstall/proc && mount --make-rslave voidinstall/proc
echo "nameserver 192.168.1.1" > voidinstall/etc/resolv.conf
echo "xbps-install -Syu xbps;  xbps-install -yu;  xbps-install -y base-system;  xbps-remove -y base-voidstrap; xbps-install -y grub xfce4 vim; ln -s /etc/sv/dhcpcd /var/service/; ln -s /etc/sv/alsa /var/service/; passwd; " >> voidinstall/hell.sh & chmod +x voidinstall/hell.sh
PS1='(chroot) # ' chroot voidinstall/ ./hell.sh
# ask the user what filesystem they want to use on it, use mkfs. accordingly, then do an (optional) bad block check using fsck -vcck

#blkid | grep sda2 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}'
# this line up here is what the contributors worked for a lot, it was hell to get regex working. this will print out the UUID of the partition the user is
#installing Void Linux on.

#blkid | grep sda2 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}' >> /etc/fstab
#this will directly get the line to /etc/fstab, one problem is that it doesn't have UUID= at the beginning of it
var=$(blkid | grep sda2 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}')
#now that works wonderfully
echo "UUID="$var >> /etc/fstab # new untested thing
