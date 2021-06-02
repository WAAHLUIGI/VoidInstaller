#!/bin/sh


#VoidX, Void Install Script, V3.0.8.5
#You are not (yet) permitted to distribute this script.
#This script is still a work in progress, and whatever happens to your
#property when you run this script is completely your responsibility!
#I, the lead developer of this script, don't take any responsibility
#for the stuff happening to your computer, or any of your property for that matter.


#To do: make an image for Windows users, make this installer a lot more appealing for
# users of other OSes (Windows, Mac, BSD, whatever's left)
#WORK ON ADDING THE EFI PARTITION TO THE FSTAB
# Work on managing UEFI/GPT / BIOS/MBR in Manual install's partitioning structure
#fetch the rootfs tarball, the sha256sums and the signatures

wget https://alpha.de.repo.voidlinux.org/live/current/void-x86_64-ROOTFS-20210218.tar.xz
wget https://alpha.de.repo.voidlinux.org/live/current/sha256sum.sig
wget https://alpha.de.repo.voidlinux.org/live/current/sha256sum.txt
wget https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/void-release-keys/files/void-release-20210218.pub


# Verify the image for security


signify -C -p void-release-20210218.pub -x sha256sum.sig void-x86_64-ROOTFS-20210218.tar.xz
sha256sum -c --ignore-missing sha256sum.txt

echo "[A]utomatic Install / [M]anual Install"
read automanualinstall
if [ $automanualinstall = "A" ] || [ $automanualinstall = "a" ]
then
	if [ -d "/sys/firmware/efi" ]
	then
		echo "This is your place to shine, Kat!"
		#My attempt at UEFI partitioning.
		
		su root -c "fdisk /dev/sdb << FDISK_CMDS
g
n
1

+1G
n
2

+30G
n
3


t
1
uefi
w
FDISK_CMDS
		partx /dev/sdb"

		# A lot more lines will replace these basic ones.
		# We will check the disk size, and determine partition
		# sizes according to that. THEN we will make filesystems
		# on the very same partitions accordingly as well.
		# The Inode sizes are fixed on ext4 filesystems,
		# so we have to be very careful about it.
		# Don't want the user to go through what I did before...
		# it was hellish. These lines are all temporary.

		su root -c "mkfs.vfat /dev/sdb1 \
		mkfs.ext4 /dev/sdb2 \
		mkfs.ext4 /dev/sdb3 \
		mkdir temp \
		mount /dev/sdb2 ./temp \
		mkdir -p ./temp/boot/efi \
		mount /dev/sdb1 ./temp/boot/efi/ \
		tar xvf void-x86_64-ROOTFS-20210218.tar.xz -C ./temp \
		echo "nameserver 192.168.1.1" > ./temp/etc/resolv.conf \
		var=$(blkid | grep sdb2 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}') \
		echo "UUID=$var	/	ext4	defaults,noatime,nodiratime	0 1" >> ./temp/etc/fstab \
		var2=$(blkid | grep sdb3 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}') \
		echo "UUID=$var2	/home	ext4	defaults,noatime,nodiratime	0 2" >> ./temp/etc/fstab \
		mount --rbind /sys ./temp/sys && mount --make-rslave ./temp/sys \
		mount --rbind /dev ./temp/dev && mount --make-rslave ./temp/dev \
		mount --rbind /proc ./temp/proc && mount --make-rslave ./temp/proc"
		su root -c "chroot ./temp/ xbps-install -Su xbps; xbps-install -Syu; xbps-install -y vim xfce4 nano grub-x86_64-efi firefox pulseaudio pavucontrol void-repo-multilib void-repo-nonfree; xbps-install -Sy steam wine wine-32bit wine-mono wine-gecko blender openshot okular atom lm_sensory; grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void" /dev/sdb; xbps-reconfigure -fa; exit"
		echo "OS should be installed. Rebooting now."
		shutdown -r now
	fi

	elif [ ! -d "/sys/firmware/efi" ]
	then
		echo "Partitioning for a BIOS system."
		echo "Checking the disk size."

		fdisk /dev/sda << FDISK_CMDS
o
n
p
1

+30G
n
p
2


w
FDISK_CMDS
		partx /dev/sda
		mkfs.ext4 /dev/sda1
		mkfs.ext4 /dev/sda2
		mkdir temp
		mount /dev/sda1 ./temp
		tar xvf void-x86_64-ROOTFS-20210218.tar.xz -C ./temp
		echo "nameserver 192.168.1.1" > ./temp/etc/resolv.conf
		#the below part will set up /etc/fstab.
		var=$(blkid | grep sda1 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}')
		echo "UUID=$var	/	ext4	defaults,noatime,nodiratime	0 1" >> ./temp/etc/fstab # I have suspicions that this will work, since $var is inside the strings of the echo command. Gotta get this tested...
		var2=$(blkid | grep sda2 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}' )
		echo "UUID=$var2	/home	ext4	defaults,noatime,nodiratime	0 2" >> ./temp/etc/fstab
		mount --rbind /sys ./temp && mount --make-rslave ./temp/sys
		mount --rbind /dev ./temp/dev && mount --make-rslave ./temp/dev
		mount --rbind /proc ./temp/proc && mount --make-rslave ./temp/proc
		
		su root -c "chroot ./temp/ xbps-install -Su xbps; xbps-install -Syu; xbps-install -y vim xfce4 nano grub firefox pulseaudio pavucontrol void-repo-multilib void-repo-nonfree; xbps-install -Sy steam wine wine-32bit wine-mono wine-gecko blender openshot okular atom lm_sensory; grub-install /dev/sda; xbps-reconfigure -fa; exit"
		echo "OS should be installed. Rebooting now."
		shutdown -r now

elif [ $automanualinstall = "M" ] || [ $automanualinstall = "m" ]
then

	echo "Do you want to partition your disk?[y/N]"

	read DISKANSWER

#these commits are getting hellish

	if [ $DISKANSWER = "y" ] || [ $DISKANSWER = "Y" ] # Whatever I fucking tried, I can't get an OR operator (||) to work at all
	then						  # If I can find a way around it we can really shorten this code, which would be great
							  # HOLY FUCKING SHIT I DID IT IT GAVE NO SYNTAX ERRORS THERE ARE NOW OR OPERATORS
		lsblk
		echo -n "What device do you want to partition? "
	
		read DISKNAME
		cfdisk /dev/$DISKNAME

	elif [ $DISKANSWER = "n" ] || [ $DISKANSWER = "N" ]
	then
		echo "Not partitioning, continuing"
	fi
	echo "What partition do you want to install Void on? \c"
	read PARTITION


	mkdir voidinstall				# make a new directory and mount it under it, since /mnt
	mount $PARTITION ./voidinstall/			# could already have something mounted on it
	rm -rf voidinstall/*
	tar xvf void-x86_64-ROOTFS-20210218.tar.xz -C ./voidinstall
	mount --rbind /sys ./voidinstall/sys && mount --make-rslave ./voidinstall/sys
	mount --rbind /dev ./voidinstall/dev && mount --make-rslave voidinstall/dev
	mount --rbind /proc ./voidinstall/proc && mount --make-rslave ./voidinstall/proc
	echo "nameserver 192.168.1.1" > ./voidinstall/etc/resolv.conf
	
	su root -c "chroot ./voidinstall /bin/bash xbps-install -Syu; xbps-install -y vim grub;"

	# ask the user what filesystem they want to use on it, use mkfs. accordingly, then do an (optional) bad block check using fsck -vcck
	
	#blkid | grep sda2 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}'
	# this line up here is what the contributors worked for a lot, it was hell to get regex working. this will print out the UUID of the partition the user is
	#installing Void Linux on.
	
	#blkid | grep sda2 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}' >> /etc/fstab
	#this will directly get the line to /etc/fstab, one problem is that it doesn't have UUID= at the beginning of it
	var=$(blkid | grep sda1 | awk -F 'UUID="' '{print $2}' | awk -F '" ' '{print $1}')
	#now that works wonderfully
	echo "UUID=$var" >> ./voidinstall/etc/fstab
	var2=$(blkid | grep sda2 | awk -F 'UUID="' '{print$2}' | awk -F '" ' '{print $1}')
	echo "UUID=$var2" >> ./voidinstall/etc/fstab
	rm sha256*
	rm void-release*
	rm void-x86_64-*
fi
