#!/bin/bash

#
# This script is intended to install/upgrade all
# software required to setup stunnel
#

# In  RHEL/CentOS-6, ip6tables does NOT support the
# "-j REDIRECT --to-ports <xx>" option
# Also, we need to disable IPv6 on such systems

echo PATH=${PATH}
STUNNEL=`which stunnel`;
LIBWRAP=`ldd $stunnel | grep libwrap`;
if [ -z $LIBWRAP ] || [  -z $DSTUNNEL ]
  then
   echo "sudo yum install openssl stunnel"
   sudo yum install openssl stunnel
fi

# get sure ip6tables is installed and ready to be used
echo " IPTABLES=`sudo which ip6tables`;"
IPTABLES=`sudo which ip6tables`;
if [ -z $IPTABLES ]
 then
	echo "sudo yum install iptables-services"
	sudo yum install iptables-services
 fi

# if firewalld is active, then it overcomes iptables and ip6tables rules 
  SYSTEMCTL="/usr/bin/systemctl"
  SERVICE="/sbin/service"
if [ -e $SYSTEMCTL ]
  then
	echo "sudo $SYSTEMCTL stop firewalld "
	sudo $SYSTEMCTL stop firewalld 
	echo "sudo $SYSTEMCTL start ip6tables"
	sudo $SYSTEMCTL start ip6tables
	echo "sudo $SYSTEMCTL start iptables"
	sudo $SYSTEMCTL start iptables
 elif [ -e $SERVICE ]
  then
	echo "sudo $SERVICE firewalld stop"
	sudo $SERVICE  firewalld stop 
	echo "sudo $SERVICE  ip6tables start"
	sudo $SERVICE  ip6tables start
	echo "sudo $SERVICE  iptables start"
	sudo $SERVICE iptables start
fi
#sudo /sbin/chkconfig  iptables on
#sudo /sbin/chkconfig  ip6tables on
