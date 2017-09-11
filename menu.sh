#!/bin/bash
#autokick menu, mwilson 2017
clear

#if [ ! -e "/usr/bin/virt-install" ] ; then
#	echo "virt-install not installed, exiting"
#	exit 1
#fi

echo "AUTOKICK - Make multiple similar VMs using Kickstart!"
discsize="16"
ramsize="2048"
cpus="1"



echo "Size of disk(s) to be created (GB): $discsize" 
echo "Ram (MB) per machine: $ramsize"
echo "VCPUs per machine: $cpus"


while true 
do
	read -p "Edit default system settings? (Y/N) " defsettingsq

	if [ "$defsettingsq" == "n" ] || [ "$defsettingsq" == "N" ] ; then
		break;

	elif  [ "$defsettingsq" == "y" ] || [ "$defsettingsq" == "Y" ] ; then

		read -e -i "$discsize" -p "Size of disk(s) to be created (GB). Default: " input
		discsize="${input:-$discsize}"

		read -e -i "$ramsize" -p "Ram (MB) per machine. Default: " input
		ramsize="${input:-$ramsize}"

		while true 
		do
			read -e -i "$cpus" -p "VCPUs per machine. Default: " input
			cpus="${input:-$cpus}"
			actualcpucnt=$(nproc) # get actual cpu count
	
			if [[ ! cpus -lt 1 ]] && [[ ! cpus -gt actualcpucnt ]] ; then
				echo "$cpus"
				break;
			else				
				echo "Error: Max VCPU is: $actualcpucnt"
				cpus="1"
			fi
		done
	break;
	fi
done




while true
do
	read -p "Number of machines? " machnum

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

exit
