#!/bin/bash

#VMGen 0.1 - (c) 2014 MWILSON
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
# It presupposes an extracted ISO and Kickstart file are available at a Web location.
# Tested with CentOS 6.6 x86_64

installtreeloc="http://X.X.X.X/EXTRACTEDISOLOCATION"
kickstartloc="\"ks=http://X.X.X.X/cent6custom.cfg\""

clear

echo "VMGen - Make multiple similar VMs using Kickstart"
echo "Number of machines?" ; read -r machnum
echo "Enter VM Name(s) and corresponding disk image(s) to be created:" ; read -r discq

discsize="8000"
read -e -i "$discsize" -p "Size of disk(s) to be created (MB). Default: " input
discsize="${input:-$discsize}"

ramsize="1024"
read -e -i "$ramsize" -p "Ram (MB) per machine. Default: " input
ramsize="${input:-$ramsize}"

for (( i=1; i<=machnum; i++ ))
	do
		echo "VM: $discq-${i} using /var/lib/libvirt/images/$discq-${i}.img ($discsize MB) will be created"
		fallocate -l ${discsize}M /var/lib/libvirt/images/$discq-${i}.img
		diskpathname="/var/lib/libvirt/images/${discq}-${i}.img"

		virt-install -n $discq-${i} -r ${ramsize} --disk path=${diskpathname} -l ${installtreeloc} -x ${kickstartloc} &
		sleep 2
	done
