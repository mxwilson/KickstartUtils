#!/bin/bash

#vmgen / autokick.sh 0.1 - (c) 2014 MWILSON

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

# This program allows multiple CentOS machines to be installed simultaneously.
# It also generates Kickstart files on the fly and automatically removes them.
# It presupposes an extracted ISO and running web server for Kickstart file.
# Tested with CentOS 6.6 x86_64

#READ COMMENTS BELOW TO FINE TUNE WEB SERVER FILE ROOT AND IP ADDRESSES


#POINT TO EXTRACTED ISO

installtreeloc="http://X.X.X.X/isodir"

clear

echo "VMGen - Make multiple similar VMs using Kickstart"
echo "Number of machines?" ; read -r machnum
echo "Enter VM Name(s), Hostname(s) and disk images(s) to be created:" ; read -r discq

discsize="8000"
read -e -i "$discsize" -p "Size of disk(s) to be created (MB). Default: " input
discsize="${input:-$discsize}"

ramsize="1024"
read -e -i "$ramsize" -p "Ram (MB) per machine. Default: " input
ramsize="${input:-$ramsize}"

echo "Enter Root password of machines:" ; read -r -s therootpw

hashrootpw=$(openssl passwd -1 "$therootpw")  # THIS HAS TO BE IN DOUBLE QUOTES OR WILL NOT WORK
hashrootsed=$(echo $hashrootpw | sed -E 's/([#$%&_\])/\\&/g') # THIS FINDS DOLLAR SIGNS AND REPLACES WITH \$ WHICH IS NEEDED IN HEREDOC BELOW FOR PASSWORDS


#BELOW WILL CREATE KICKSTART FILES AND PLACE THEM IN ROOT DIR OF WEBSERVER

for (( i=1; i<=machnum; i++ ))
	do
		cat > "/var/www/html/${discq}-${i}.cfg" <<endmsg

install
lang en_US.UTF-8
text
keyboard us

network --onboot yes --device eth0 --bootproto dhcp --noipv6 --hostname ${discq}-${i}
rootpw --iscrypted $hashrootsed
firewall --service=ssh
authconfig --enableshadow --passalgo=sha512
selinux --enforcing
timezone --utc America/Toronto

bootloader --location=mbr --driveorder=vda --append="crashkernel=auto rhgb quiet"
clearpart --all --drives=vda

#zerombr should disable disk warning
zerombr
part /boot --fstype=ext4 --size=500
part pv.253002 --grow --size=1
volgroup vg_1 --pesize=4096 pv.253002
logvol / --fstype=ext4 --name=lv_root --vgname=vg_1 --grow --size=1024 --maxsize=51200
logvol swap --name=lv_swap --vgname=vg_1 --grow --size=819 --maxsize=819

%packages --nobase
@core
openssh-clients
openssh-server
wget
nano
ntp
%end

#%post --interpreter /bin/bash
#useradd -p 'some encrypted password' someusername
#%end

reboot

endmsg
		
		#CHANGE TO WEBSERVER ADDRESS WHERE KICKSTARTS WILL BE AVAILABLE
		kickstartloc="\"ks=http://X.X.X.X/${discq}-${i}.cfg\""
		echo "VM: $discq-${i} using /var/lib/libvirt/images/$discq-${i}.img ($discsize MB) will be created"
		fallocate -l ${discsize}M /var/lib/libvirt/images/$discq-${i}.img
		diskpathname="/var/lib/libvirt/images/${discq}-${i}.img"

		virt-install -n $discq-${i} -r ${ramsize} --disk path=${diskpathname} -l ${installtreeloc} -x ${kickstartloc} &

		sleep 2
	done

sleep 60
for (( i=1; i<=machnum; i++ ))
do
echo "Deleting Kickstart: ${discq}-${i}.cfg"
#BE SURE TO CHANGE WEBSERVER DIR IF NEEDED
rm /var/www/html/${discq}-${i}.cfg
done
