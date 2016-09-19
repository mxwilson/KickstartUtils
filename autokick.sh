#!/bin/bash

# AUTOKICK.SH 0.2 - (c) 2016 MWILSON

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#any later version.
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#GNU General Public License for more details.
#You should have received a copy of the GNU General Public License
#along with this program. If not, see <http://www.gnu.org/licenses/>.

# This program allows multiple CentOS/RHEL 7 machines to be installed simultaneously.
# It also generates Kickstart files on the fly and automatically removes them.
# It presupposes an a running webserver hosting the extracted ISO and Kickstart file.
# Must be run with superuser privileges.

# Tested with CentOS 7 x86_64

#READ COMMENTS BELOW TO FINE TUNE WEB SERVER FILE ROOT AND IP ADDRESSES

#POINT TO URL OF EXTRACTED ISO
installtreeloc="http://XXX.XXX.XXX.XXX/ks/iso/rh/"

#POINT TO URL OF DIRECTORY THAT WILL CONTAIN KICKSTART FILES
ksurldir="http://XXX.XXX.XXX.XXX/ks/"

#LOCATION OF WEBSERVER DIR FOR KICKSTART FILES
webserverdir="/var/www/html/ks/"

#DIRECTORY CONTRAINING LIBVIRT IMAGES
libvirtdir="/var/lib/libvirt/images/"

#REQUIRED TO USE VIRSH CONSOLE
extraargs="console=tty0 console=ttyS0,115200n8 ip=dhcp"

clear

if [ ! -e "/usr/bin/virt-install" ] ; then
	echo "virt-install not installed, exiting"
	exit
fi

echo "AUTOKICK - Make multiple similar VMs using Kickstart!"

while true
do
	read -p "Number of machines? " machnum

	if [[ "$machnum" =~ ^[0-9]+$ ]] && [[ $machnum -gt 0 ]]; then
		break
	else
		echo "Try again."
	fi
done

echo "Enter VM Name(s), Hostname(s) and disk images(s) to be created:" ; read -r discq

if [ -e "${libvirtdir}${discq}-1.img" ]; then
        echo "VM name exists, exiting";
        exit
fi

discsize="8"
read -e -i "$discsize" -p "Size of disk(s) to be created (GB). Default: " input
discsize="${input:-$discsize}"

ramsize="1024"
read -e -i "$ramsize" -p "Ram (MB) per machine. Default: " input
ramsize="${input:-$ramsize}"

cpus="1"
read -e -i "$cpus" -p "VCPUs per machine. Default: " input
cpus="${input:-$cpus}"

while true
do
	echo "Enter root password of machines:" ; read -r -s therootpw
	echo "Enter root password again:" ; read -r -s therootpw2

	if [ ${therootpw} = ${therootpw2} ]; then
		break
	else
		echo "Passwords do not match."
	fi
done

hashrootpw=$(openssl passwd -1 "$therootpw")  # HAS TO BE IN DOUBLE QUOTES 
hashrootsed=$(echo $hashrootpw | sed -E 's/([#$%&_\])/\\&/g') # FINDS DOLLAR SIGNS AND REPLACES WITH \$ WHICH IS NEEDED IN HEREDOC BELOW FOR PASSWORDS

#BELOW WILL CREATE KICKSTART FILES AND PLACE THEM IN WEBSERVER DIR SPECIFIED ABOVE

for (( i = 1; i <= machnum; i++ ))
do
	cat > "${webserverdir}${discq}-${i}.cfg" <<endmsg
install
text
lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts='us'
timezone America/New_York
auth --enableshadow --passalgo=sha512
selinux --enforcing
firewall --enabled --service=ssh
services --enabled=NetworkManager,sshd
eula --agreed
ignoredisk --only-use=vda
reboot 

bootloader --location=mbr --boot-drive=vda
zerombr
clearpart --all --drives=vda
autopart --type=lvm

rootpw --iscrypted ${hashrootsed}

%packages
@core
%end

#give random numbered hostname to machine

%pre
#!/bin/sh
echo "network --device=eth0 --bootproto=dhcp --noipv6 --activate --hostname=`echo ${discq}-${i}-$RANDOM`" > /tmp/ks-network-hostname
%end

%include /tmp/ks-network-hostname

%post
yum -y update
%end

#%post --interpreter /bin/bash
#useradd -p 'some encrypted password' someusername
#%end

endmsg
		
	#FINALLY ADD THE EXTRA CONSOLE ARGS TO KS LOCATION AND BEGIN VIRT-INSTALL
	kickstartloc="${extraargs} ks=${ksurldir}${discq}-${i}.cfg"
		
 	echo "VM: ${discq}-${i} using ${libvirtdir}$discq-${i}.img (${discsize} GB) will be created"
        diskpathname="${libvirtdir}${discq}-${i}.img"
        
	#MORE THAN ONE MACHINE, SEND INSTALL TO BACKGROUND 
	if [ ${machnum} -gt "1" ]; then
		nohup virt-install --name=${discq}-${i} --disk path=${diskpathname},size=${discsize} --ram=${ramsize} --vcpus=${cpus} --os-variant=rhel7 --accelerate --nographics --location=${installtreeloc} --extra-args="${kickstartloc}" &>/dev/null &
	else
		virt-install --name=${discq}-${i} --disk path=${diskpathname},size=${discsize} --ram=${ramsize} --vcpus=${cpus} --os-variant=rhel7 --accelerate --nographics --location=${installtreeloc} --extra-args="${kickstartloc}"
	fi

	sleep 5
done

exit
