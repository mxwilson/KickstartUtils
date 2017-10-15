#!/bin/bash

# AUTOKICK.SH 0.3.1 (c)2017 MWILSON <https://github.com/mxwilson/KickstartUtils>

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

# Tested with CentOS 7.3 x86_64

#READ COMMENTS BELOW TO FINE TUNE WEB SERVER FILE ROOT AND IP ADDRESSES

#POINT TO URL OF EXTRACTED ISO
installtreeloc="http://localhost/ks/iso/centos"

#POINT TO URL OF DIRECTORY THAT WILL CONTAIN KICKSTART FILES
ksurldir="http://localhost/ks/"

#LOCATION OF WEBSERVER DIR FOR KICKSTART FILES
webserverdir="/var/www/html/ks/"

#DIRECTORY CONTRAINING LIBVIRT IMAGES
libvirtdir="/vm/img/"

#REQUIRED TO USE VIRSH CONSOLE
extraargs="console=tty0 console=ttyS0,115200n8 ip=dhcp"

#DELETE THE GENERATED KICKSTART FILE UPON EXIT (yes/no)
del_kick="no"

clear

if [ ! -e "/usr/bin/virt-install" ] ; then
	echo "Error: virt-install not installed, exiting"
	exit 1
fi

echo "AUTOKICK - Make multiple similar VMs using Kickstart!"

discsize="16"
ramsize="2048"
cpus="1"

echo "Size of disk(s) to be created (GB): $discsize" 
echo "Ram (MB) per machine: $ramsize"
echo "VCPUs per machine: $cpus"

while true 
do
	read -p "Edit default system settings? (Y/N) " defs

	if [ "$defs" == "n" ] || [ "$defs" == "N" ] || [ "$defs" == "no" ] ; then
		break;
	
	elif  [ "$defs" == "y" ] || [ "$defs" == "Y" ] || [[ "$defs" == "yes" ]]; then

		while true
		do
	
			read -e -i "$discsize" -p "Size of disk(s) to be created (GB). Default: " input
			discsize="${input:-$discsize}"
			
			if ! [[ "$discsize" =~ ^[0-9]+$ ]] ; then
				echo "Error"
				discsize="16"
				continue;
			fi

			if [[ "$discsize" -lt 8 ]] ; then
				echo "Error: 8 GB disk required for this install"
				discsize="16"
				continue;
			else
				break;
			fi

		done
			
		while true
		do
			read -e -i "$ramsize" -p "Ram (MB) per machine. Default: " input
			ramsize="${input:-$ramsize}"

			if ! [[ "$ramsize" =~ ^[0-9]+$ ]] ; then
				echo "Error"
				ramsize="2048"
				continue;
			fi

			if [[ "$ramsize" -lt 1280 ]] ; then
				echo "Error: 1280 MB Ram required for this install"
				ramsize="2048"
				continue;
			else
				break;
			fi
		done

		while true 
		do
			read -e -i "$cpus" -p "VCPUs per machine. Default: " input
			cpus="${input:-$cpus}"
			actualcpucnt=$(nproc) # get actual cpu count
		
			if ! [[ "$cpus" =~ ^[0-9]+$ ]] ; then
				echo "Error"
				cpus="1"
				continue;
			fi

			if [[ ! cpus -lt 1 ]] && [[ ! cpus -gt actualcpucnt ]] ; then
				break;
			else				
				echo "Error: Max VCPU is: $actualcpucnt"
				cpus="1"
				continue;
			fi
		done
		break;
	fi
done

while true
do
	read -p "Number of virtual machines to launch? " machnum

	if [[ "$machnum" =~ ^[0-9]+$ ]] && [[ $machnum -gt 0 ]]; then
		break;
	else
		echo "Try again."
	fi
done

echo "Enter VM Name(s), Hostname(s) and disk images(s) to be created:" ; read -r discq

if [ -e "${libvirtdir}${discq}-1.img" ]; then
        echo "VM name exists, exiting";
        exit
fi

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
timezone America/New_York --isUtc
auth --enableshadow --passalgo=sha512
selinux --enforcing
firewall --enabled --service=ssh
services --enabled=NetworkManager,sshd
eula --agreed
reboot 

ignoredisk --only-use=vda
clearpart --none --initlabel
bootloader --location=mbr --boot-drive=vda
zerombr

part /boot --size=512 --ondisk vda --fstype=ext4
part pv.01 --size=1 --ondisk vda --grow
volgroup vg1 pv.01
logvol / --vgname=vg1 --size=10000 --name=root --fstype=ext4 --grow
logvol swap --vgname=vg1 --recommended --name=swap --fstype=swap

rootpw --iscrypted ${hashrootsed}

%packages
@core
tmux
vim
net-tools
%end

%addon com_redhat_kdump --disable --reserve-mb='auto'
%end

#give random numbered hostname to machine

%pre
#!/bin/sh
echo "network --device=eth0 --bootproto=dhcp --noipv6 --activate --hostname=`echo ${discq}-${i}-$RANDOM`" > /tmp/ks-network-hostname
%end

%include /tmp/ks-network-hostname

#update the system after install

%post
#yum -y update
%end

#add additional users if required

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
		sleep 10
	else
		virt-install --name=${discq}-${i} --disk path=${diskpathname},size=${discsize} --ram=${ramsize} --vcpus=${cpus} --os-variant=rhel7 --accelerate --nographics --location=${installtreeloc} --extra-args="${kickstartloc}"
	fi  
done

#delete the generated Kickstart file

if [ "$del_kick" == "yes" ] ; then
	for (( i=1; i<=machnum; i++ ))
	do
		sleep 10
		pgrep virt-install
		res=$?

		if [[ "$res" -eq 1 ]] ; then 
			echo "Deleting Kickstart file: ${discq}-${i}.cfg"
			rm ${webserverdir}${discq}-${i}.cfg
		else
			sleep 5
			continue;	
		fi
	done
fi

exit
