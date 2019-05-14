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
if [ -z $LIBWRAP ]
  then
   echo "sudo yum install openssl stunnel"
   sudo yum install openssl stunnel
fi

# get sure ip6tables is installed and ready to be used
echo "sudo yum install iptables-services"
sudo yum install iptables-services

# if firewalld is active, then it overcomes iptables and ip6tables rules 
echo "sudo systemctl stop firewalld "
sudo systemctl stop firewalld 
echo "sudo systemctl start ip6tables"
sudo systemctl start ip6tables
echo "sudo systemctl start iptables"
sudo systemctl start iptables


#sudo /sbin/chkconfig  iptables on
#sudo /sbin/chkconfig  ip6tables on
