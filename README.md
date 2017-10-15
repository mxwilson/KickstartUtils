# RHEL/CentOS 7+ Kickstart Generator 

## autokick.sh (0.3.1)

## Synopsis

This program allows multiple CentOS/RHEL 7+ machines to be installed simultaneously using KVM virtualization. It generates Kickstart files on the fly to be used by the installer. 

## Requirements
KVM/Libvirt, Running webserver containing extracted ISO, Superuser privileges.

A few variables must be changed prior to running this program:

installtreeloc – URL of extracted ISO.

ksurldir – URL of directory that will contain Kickstart files.

webserverdir – Local directory of Kickstart files.

libvirtdir – Local directory of libvirt image files.

Tested on CentOS 7.3.1611.

## Notes

Passwords are hashed and dropped into the KS file being created.

Hostnames are suffixed with a random number which is helpful if many machines are being created at once.

Networking is automatically configured using DHCP to assign IP addresses. 

## License

Copyright 2015-17, Matthew Wilson.
License GPLv3+: GNU GPL version 3 or later http://gnu.org/licenses/gpl.html.
No warranty. Software provided as is.
