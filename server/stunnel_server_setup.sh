#!/bin/bash 

##################################################################### 
# SSL server Wrapper
# initial version: Apr 2019 - Alberico Perrella Neto
#####################################################################
print_info()
{
  local INFO=$1

  if [ "$INFOLEVEL" != "0" ]
   then
     echo $INFO
  fi
}

get_redhat_version()
{
  local STR=" -- get_redhat_version - "
  RHVERSION=`cat /etc/redhat-release  | awk '{ print $7 }' | cut -d. -f 1`;
  print_info "$STR RHEL version=$RHVERSION -- "
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

add_param()
{ 
  local ORIGFILE=$1
  local ENTRY="$2 $3 $4"
  local STR=" -- add_param - "
  local TMPFILE="entry.tmp"
  local LEAVE="no"

  echo > $TMPFILE

  cat $ORIGFILE |
   while read LINE
   do
    if [ "$LINE" == "" ]
    then
        continue
    fi
    if [ "$LINE" == "$ENTRY" ]
    then
        LEAVE="yes"
        rm $TMPFILE
        break
    fi
    if [ "$LINE" == "}" ]
     then
        echo "$STR echo $ENTRY >> $TMPFILE -"
        echo $ENTRY >> $TMPFILE
     fi
     echo "$STR echo $LINE >> $TMPFILE -"
     echo $LINE >> $TMPFILE
   done

  if [ "$LEAVE" == "no" ] && [ -e $TMPFILE ]
   then
         echo "$STR sudo cp $TMPFILE  $ORIGFILE -"
        sudo cp $TMPFILE  $ORIGFILE
  fi

}

rebind_oscssd()
{
  local STR=" -- rebind_oscssd -"
  local OSCNAME=$1
  local OSCPORT=$2
  if [ -z $OSCNAME ] || [ -z $OSCPORT ]
   then
        echo "$STR we could not identify one of oscname=[$OSCNAME] OR oscport=[$OSCPORT] -"
        echo "$STR Skippiong now!... -"
        exit 3;
   fi

  local OSCFILE="/etc/xinetd.d/${OSCNAME}"
  if [ ! -e $OSCFILE ]
   then
        echo "$STR The oscFile=[$OSCFILE] does not exist. Skipping now !... -"
        exit 4;
   fi
  
  local THISHOST=`hostname`;
  if [ "$THISHOST" == "" ]
   then
        echo "$STR Could not identify this host=[$THISHOST]. Skipping now !... -"
        exit 5;
   fi

#  rebind the oscXYZ service to the loopback interface if usimg RHEL6, because the 
#  ip6tables version there cannot redirect TCP6 packets
#  local IPADDR=`ping -c 1 $THISHOST | grep PING | cut -d\( -f 2 | cut -d\) -f 1`;
#  if [ "$IPADDR" == "" ]
#   then
#        echo "$STR Could not identify the IPv4  address =[$IPADDR]  of this host. SKIP NOW! -"
#        exit 6;
#   fi

#  local PARAMETER="  bind = $IPADDR  "
  local PARAMETER="  bind = 127.0.0.1  "
  add_param $OSCFILE $PARAMETER
  
  # restart the xinetd
  SYSTEMCTL="/usr/bin/systemctl"
  SERVICE="/sbin/service"
  XINETD="/etc/init.d/xinetd"

  if [ -e $XINETD ]
   then
        echo "$STR sudo $XINETD restart - "
        sudo $XINETD restart
  elif [  -e $SERVICE ]
   then
        echo "$STR sudo $SERVICE xinetd restart -"
        sudo $SERVICE xinetd restart
  elif [  -e $SYSTEMCTL ]
   then 
        echo "$STR sudo $SYSTEMCTL restert xinetd -"
        sudo $SYSTEMCTL restert xinetd
  else
        echo "$STR Could not restart the $OSCNAME via xinetd -"
        echo "$STR [$PARAMETER] binding failed!  -"
  fi

}


get_osc_portnr()
{
  local STR=" -- get_osc_portnr - "
  local OSCSSD=$1
  local SERVFILE="/etc/services"
  # the first list has the osc name, while the second list has the port number
  local OSC_LIST1=`grep $OSCSSD  $SERVFILE | awk '{ print  $1  }'`;
  local LIST2=`grep $OSCSSD  $SERVFILE | awk '{ print $2 }'`;
  local COUNTER=0

  if [ "$OSC_LIST1" == "" ]
   then
        echo "$STR Something went very wrong! --"
        echo "$STR No $OSCSSD service was found! Skipping now... --"
        exit 1002
   fi

  for NAME in $OSC_LIST1
   do
     COUNTER=` expr $COUNTER + 1`;
     if [ "$NAME" == "$OSCSSD" ]
      then
        print_info "$STR  Counter = $COUNTER - Osc_name= [$NAME] matches service = [$OSCSSD] --"
        break;
     fi
   done
  local OSC_DPORT=` echo $LIST2 | awk '{ print $"${COUNTER}" }'`;
  print_info "$STR  Counter=$COUNTER - $NAME is into the list: [$OSC_DPORT] --"
  OSC_PORT=`echo $OSC_DPORT | cut -d/ -f 1`;
  echo "$STR OSC_PORT = [$OSC_PORT] --"
##############################################################################
# In case IPv6 is enabled and the stunnel-server is installed on a RHEL-6 system, then the default ip6table version installed ( ip6tables v1.4.7 ) does not support the creation of the ip6table REDIRECT rules. In such a case, the iptable REDIRECTrules are the only option. In this situation the <bind = <IPv4>> parameter ( the <IPv4> is the IPv4 address of this stunnel-server machine ) should be added to the osc* (Versant Service Connector) file, which is normally located in the /etc/xinet.d/ directory. The xinetd must be restarted to listen to new client connections on the socket configured in the /etc/services file ( osc*	<port>/tcp);
##############################################################################
  get_redhat_version
  if [ "RHVERSION" == "6" ]
   then
    rebind_oscssd $OSCSSD $OSC_PORT
  fi 
 print_info "|------------------- $STR end  -------------------------------------------------|"
}

get_ip_version()
{
  local STR=" -- get_ip_version - "
  local OSCN=$1

  if [ $# != 1 ]
   then
	print_info "$STR got the foillowing parameters: [$@] "
	exit 1001
  fi

  get_osc_portnr $OSCN

  local AUX=`echo lsof -i :$OSC_PORT`;
  echo "$STR sudo $AUX";
  local TYPE=`sudo $AUX | grep -v COMMAND | awk '{ print $5 }' `;
  print_info "$STR TYPE= [$TYPE] --"

  if [ "$TYPE" == "IPv4" ]
    then
	IPVERSION=4
    else	# IPv6
	IPVERSION=6
  fi
  echo "$STR Parameters:[$@] - number of Parameters: $# - IPv${IPVERSION} --"
 print_info "|------------------- $STR end  -------------------------------------------------|"
}

get_osc_service_def()
{
  local STR=" -- get_osc_service_def - "
  OSC_ACTIVE_LIST=`netstat -a | grep osc | cut -d: -f 2 | awk '{print $1}'`;
  OSC_NAME=`echo $VERSANT_SERVICE_NAME`;
  if [ -z $OSC_NAME ] 
   then 	#VERSANT_SERVICE_NAME is not defined
    # we should verify if the default oscssd is active
    for OSC in $OSC_ACTIVE_LIST
     do
	if [ $OSC == "oscssd" ]
	 then
	   OSC_NAME=$OSC
           #### The osc service was found  
  	     get_ip_version $OSC
	     echo "$STR OSC_NAME=$OSC_NAME - OSC_PORT=$OSC_PORT --"
	     return 0
	   ####
        fi
     done
    # now we need to double check if VERSANT_SERVICE_NAME matches one of the active osc services
   else
    FLAG_L="FALSE"
    for OSC in $OSC_ACTIVE_LIST
     do
        if [ $OSC == $OSC_NAME ]
         then
           FLAG_L="TRUE"
           #### The osc service was found  
  	     get_ip_version $OSC
	     echo "$STR OSC_NAME=$OSC_NAME - OSC_PORT=$OSC_PORT --"
	     return 0
	   ####
        fi
     done
    if [ $FLAG_L == "FALSE" ]
     then
	echo "$STR The $OSC_NAME is not listenning for connection requests! --"
	echo "$STR get_osc_service_def - Exiting now!... --"
	exit 1000
    fi
  fi #### if [-z $OSC_NAME] -- else ####
 print_info "|------------------- $STR end  -------------------------------------------------|"
}

stopIF_hostname_null()
{
  local STR=" -- stopIF_hostname_null - "
  local THIS_HOST=$1
  if [ -z $THIS_HOST ]
   then
     echo "$STR Could not get this hostname ($THIS_HOST)! Exiting now ... --"
     exit 1001
  fi
  local LOCAL_HOST=$THIS_HOST
  # verify if the hostnae is a full qualified name
  # in case it is not a full qualified name, then set it up
  local DOTS=`echo $THIS_HOST | grep -o '\.' | wc -l`;
  local NFIELD=`expr $DOTS + 1`;
  local LASTFIELD=`echo $THIS_HOST | cut -d. -f $NFIELD`;
  print_info "$STR Last domain field = [$LASTFIELD]   --"
  if [ "$LASTFIELD" != "com" ] && [ "$LASTFIELD" !=  "org" ] && [ "$LASTFIELD" != "net" ] && [ "$LASTFIELD" != "int" ] && [ "$LASTFIELD" != "edu" ] && [ "$LASTFIELD" != "gov" ] && [ "$LASTFIELD" != "mil" ]
   then
     print_info "$STR This hostname = $THIS_HOST - Last Field =[$LASTFIELD]--"
     local ANSWER="no"
     while [ "${ANSWER:0:1}" != "y" ] 
      do
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo -n "$STR Please enter the domain name of this network (example: versant.com):"
	read DOMAIN
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo -n "$STR Is this domain correct? (yes|no):"
	read ANSWER
        if [ "${ANSWER:0:1}" == "Y" ]
          then
                ANSWER="yes"
        fi
      done
      LOCAL_HOST=$THIS_HOST.${DOMAIN}
  fi
  echo "$STR Full Qualified hostname= $LOCAL_HOST --"
  SSL_SERVER_HOST=$LOCAL_HOST
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

check_socket()
{
   # this function should set the socket to NULL if
   # the passed port does not match the port assigned to
   # this socket

   local STR=" -- check_socket - "
   local SOCKET=$1
   local PORT=$2
   
   # we still need to verify if we got the right port number
   # Socket could be an IPv4 or IPv6 socket
   if [ "SOCKET" != "" ]
     then
       # identify the amount of collons (:) and take the last field
       local DOTS=`echo $SOCKET | grep -o ':' | wc -l`;
       local NFIELD=`expr $DOTS + 1`;
       local LASTFIELD=`echo $SOCKET | cut -d: -f $NFIELD`;
       print_info "$STR This socket uses the Port [$LASTFIELD] -- "
        if [ "$LASTFIELD" != "$PORT" ]
          then
            SOCKET=""
        fi
   fi
  echo "$STR Returning socket flag =[$SOCKET] --"
  echo "$STR In case the socket flag is empty, then the port [$PORT] is available --"
 print_info "|------------------- $STR end  -------------------------------------------------|"
}

search_ssl()
{
  local STR=" -- search_ssl - "
  local SERV=$1
  local PORT=$2

  local AUX0=`grep $SERV  /etc/services  | cut -d/ -f 1 `;
   TEST0=`echo $AUX0 | awk '{ print $1}' `;   # service name
   TEST1=`echo $AUX0 | awk '{ print $2}' `;   # service port
   #TEST2=`netstat -an | grep  \":$PORT \" | awk '{print $4}' `;
   TEST2=`netstat -an | awk '{ print $4 }' | grep  :$PORT `;

   # still need to verify if we got the right port number
   # TEST2 could be an IPv4 or IPv6 socket
   check_socket $TEST2 $PORT   
   TEST2=$SOCKET

 if [ -z $TEST0 ] && [ -z $TEST1 ] && [ -z $TEST2 ]
  then
    print_info "$STR The $SERV and $PORT are available --"
    local RET="FALSE"
  else
    print_info "$STR The $SERV and $PORT are NOT available --"
    local RET="TRUE"
 fi
 # Returning $RET
 RESULT=$RET
 echo "$STR Result = [$RESULT] --"
 print_info "|------------------- $STR end  -------------------------------------------------|"
}

verify_client_port()
{
   local STR=" --verify_client_port - "
   local CLHOST=$1
   local CLPORT=$2
   # Local <IP:port> is the fourthy field of "netstat -an"
   local LOCALSOCKET=`print_info "netstat -an | awk '{ print $4 }' | grep :$CLPORT" `;
    print_info "$STR LOCALSOCKET=[$LOCALSOCKET] --"
   CLSOCKET_FLAG=`ssh $CLHOST $LOCALSOCKET `;
   print_info "$STR Complete SSH output = [$CLSOCKET_FLAG] --"
   CLSOCKET_FLAG=`echo $CLSOCKET_FLAG | awk '{ print $4 }'`;
   print_info "$STR Client socket = [$CLSOCKET_FLAG] --"

   # still need to verify if we got the right port number
   # in case the port of CLSOCKET_FLAG does NOT matche the
   # passed CLPORT, then check_socket returns NULL

   check_socket $CLSOCKET_FLAG $CLPORT
   CLSOCKET_FLAG=$SOCKET

   echo "$STR In case CLSOCKET_FLAG is empty, then the port is available in the remote host --"
   echo "$STR Remote Client socket Flag = [$CLSOCKET_FLAG] -- "
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

get_ssl_service_def()
{
  local STR=" -- get_ssl_service_def - "
  if [ $# != 2 ]
    then
	echo "$STR passed the wong number of parameters --"
	echo "$STR Parameters: sslPort target --"
	echo "$STR target SHOULD BE server or anyrhing else (= client) --"
	echo "$STR Exiting --"
	exit 1004
  fi
  
  local SSLPORT=$1
  # get sure to not use the full qualified name to define the service name
  local THISHOST=`echo $2 | cut -d\. -f 1`;

  print_info "$STR ServicePort = $SSLPORT - Target = $THISHOST --"

  # I need to setup the name of the SSL_service before start to verify
  # if its name and port numbers are available   

	SSL_SERVER_NAME="ssl_srv_${THISHOST}"
	echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo -n "$STR Enter an additional string to be added to the ServiceName of the SSL wrapper server [$SSL_SERVER_NAME]:"
	read MYSTR
	SSL_SERVER_NAME=${SSL_SERVER_NAME}_${MYSTR}
	echo "$STR (server) ServiceName = $SSL_SERVER_NAME --"
	search_ssl $SSL_SERVER_NAME $SSLPORT;

 # This should be verified later on the client machines
	SSL_CLIENT_NAME="ssl_cln_${THISHOST}_${MYSTR}"
	echo "$STR (client) ServiceName = $SSL_CLIENT_NAME --"

  print_info "|------------------- $STR end  -------------------------------------------------|"
}

check_one_client()
{
   local STR=" -- check_one_client - "
   print_info "$STR We need to check if the SSL client port you wish to use is available --"
   echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"		
   echo -n "$STR Enter a client hostname:"
   read REMOTEHOST
   CLSOCKET_FLAG="xx"
   while [ "$CLSOCKET_FLAG" != "" ]
    do
      echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++"		
      echo -n "$STR Enter the SSL client port you wish to use: "
      read REMOTEPORT
      verify_client_port $REMOTEHOST $REMOTEPORT
    done
   echo  "$STR The client hostname [$REMOTEHOST] is not using the port [$REMOTEPORT] --"
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

self_signed_certificate()
{
  local HOST=$1
  local STR="  -- self_signed_license - "
  CERTNAME="cert_${SSL_SERVER_NAME}.pem"

  if [ ! -e ${STUNNELDIR}/${CERTNAME} ]
   then
     echo "$STR an SSL self signed certificate will be generated --"
     echo "$STR Please enter the information required on the next lines --"
     echo  
     echo "$STR sudo make -f /etc/pki/tls/certs/Makefile $CERTNAME --"
     sudo make -f /etc/pki/tls/certs/Makefile $CERTNAME
     local CERT=`ls $CERTNAME`
     if [ -z $CERT ]
      then
        echo "$STR NO self signed certificate was created! --"
        echo "$STR stunnel needs a SSL certificate --"
      else
        echo "$STR sudo cp $CERTINAME $STUNNELDIR/. --"
        sudo cp $CERTNAME $STUNNELDIR/.
     fi
   else
      echo "$STR The $CERTNAME file already exists under the $STUNNELDIR directory--"
      echo "$STR Don't need to create a new certificate --"
  fi
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

add_entries()
{
  local STR=" -- add_entries - "
  local TMPFILE=$1
  local TARGETFILE=$2
  echo "$STR Add entries to the $TARGETFILE ... -- "
  cat $TMPFILE |
   while read LINE
    do
        # verify if the service definition already exists before insert it
      local SERVICE=`echo $LINE | awk '{ print $1 }'`;
      if [ ! -z $SERVICE ]
       then
        MATCH1=`grep $SERVICE $TARGETFILE`;
        if [ "$MATCH1" == "" ]
         then
         # The next is valid only for the tmp_services and /etc/services files
          if [ "$TARGETFILE" == "/etc/services" ]
          then
           local PORT_TCP=`echo $LINE | awk '{ print $2 }' `;
           MATCH2=`grep " $PORT_TCP" $TARGETFILE`;
           if [ "$MATCH2" == "" ]
           then
             echo "$STR echo $LINE |sudo tee -a $TARGETFILE -"
             echo $LINE |sudo tee -a $TARGETFILE
           fi # end [ -z $MATCH2 ]

          else
           echo "$STR echo $LINE |sudo tee -a $TARGETFILE -"
           echo $LINE |sudo tee -a $TARGETFILE
          fi # end [ "$TARGETFILE" == "/etc/services" ]

        fi # end [ -z $MATCH1 ]
      fi # end  [ ! -z $SERVICE ]
    done
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

set_hosts_allow()
{
   HOSTS_ALLOW_FILE="/etc/hosts.allow"
   TMP_HOSTS_ALLOW="./tmp_hosts.allow_$SSL_SERVER_NAME"
   echo "" > $TMP_HOSTS_ALLOW
   for SERVN in $SSL_SERVER_NAME $SSL_CLIENT_NAME $OSC_NAME
     do
        echo "$SERVN    : ALL" | tee -a $TMP_HOSTS_ALLOW
     done
    # Now that we have a temporary file, add these entries to
    # the /etc/hosts.allow file
    add_entries $TMP_HOSTS_ALLOW $HOSTS_ALLOW_FILE
}

set_iptable_rule()
{
  local STR=" -- set_iptable_rule - "

  if [ "$RHVERSION" == "6" ]
   then 
	# This should be used to force a RHEL-6 machine to use iptables instead of ip6tables
	# because the ip6tables version delivered on RHEL-5 does not support the 
	# -j REDIRECT rule 
	IPVERSION="4"
  fi

  if [ "$IPVERSION" == "4" ]
   then
       local COMM1="iptables"
       local COMM2="ping"
   else
       local COMM1="ip6tables"
       local COMM2="ping6"
  fi

  IPADDRESS=`$COMM2 -c 1 $SSL_SERVER_HOST | grep PING | cut -d\( -f 2 | cut -d\) -f 1`;
  print_info "$STR IPADDRESS = [$IPADDRESS] -- "
  if [ -z $IPADDRESS ]
   then
        echo "$STR Could not get through ping IPv${IPVERSION} the IP adress of [$SSL_SERVER_HOST] --"
        echo "$STR Skipping now! -- "
        exit 1005
  fi

  TMP_IPTABLE_CLN_RULE_FILE="./tmp_iptable_${SSL_CLIENT_NAME}.cfg"
  local RULE="$COMM1 -t nat -A OUTPUT -p tcp --dest $IPADDRESS --dport $OSC_PORT -j REDIRECT --to-ports $REMOTEPORT "
  echo "$RULE" > $TMP_IPTABLE_CLN_RULE_FILE
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

set_services()
{  
   SERVICES_FILE="/etc/services" 
   TMP_SERVICES="./tmp_services_$SSL_SERVER_NAME"
   echo "" > $TMP_SERVICES
    echo "$SSL_SERVER_NAME  $SSL_SERVER_PORT/tcp " | tee -a $TMP_SERVICES
    echo "$SSL_CLIENT_NAME  $REMOTEPORT/tcp " | tee -a $TMP_SERVICES

    # Now that we have a temporary file, add these entries 
    # to the /etc/services file of the server host
    # Notice that the osc* service is already defined 
    # and active on the server host
    add_entries $TMP_SERVICES $SERVICES_FILE

    # add the osc service entry to the temp file, which
    # would ONLY be user later by the client hosts
        echo "$OSC_NAME  $OSC_PORT/tcp " | tee -a $TMP_SERVICES
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

pack_all_client_config_files()
{
  local STR=" -- pack_all_client_config_files -"
   local CLIENTFILE="client_config.txt"
   local THISDIR=`pwd`
   echo "VERSANT_SERVICE_NAME = $VERSANT_SERVICE_NAME" > $CLIENTFILE
   echo "VERSANT_SERVICE_PORT = $OSC_PORT" >> $CLIENTFILE
   echo "DAEMONMODE = $DAEMONMODE" >> $CLIENTFILE
   echo "STUNNELDIR = $STUNNELDIR" >> $CLIENTFILE
   echo "TMP_SERVICES = $TMP_SERVICES" >> $CLIENTFILE
   echo "TMP_IPTABLE_CLN_RULE_FILE = $TMP_IPTABLE_CLN_RULE_FILE" >> $CLIENTFILE
   echo "TMP_HOSTS_ALLOW = $TMP_HOSTS_ALLOW" >> $CLIENTFILE
   echo "CLN_CFG_FILE = $CLN_CFG_FILE" >> $CLIENTFILE
   local TMP_CERTFILE=""
   if [ -e ${STUNNELDIR}/${CERTNAME} ]
     then
	echo "CERTNAME = $CERTNAME" >> $CLIENTFILE
        echo "$STR sudo -- bash -c 'cp ${STUNNELDIR}/${CERTNAME} ${THISDIR} ; chmod a+r $CERTNAME' --" 
        #sudo -- bash -c 'cp ${STUNNELDIR}/${CERTNAME} $THISDIR/.  ; chmod a+r $CERTNAME'; 
        sudo  cp ${STUNNELDIR}/${CERTNAME} $THISDIR/.   
        sudo  chmod a+r $CERTNAME  
        TMP_CERTFILE=$CERTNAME
   fi
   TARFILE="client_conf_${SSL_SERVER_NAME}.tgz"
   tar cvpfz $TARFILE $CLIENTFILE $TMP_SERVICES $TMP_IPTABLE_CLN_RULE_FILE $TMP_HOSTS_ALLOW $CLN_CFG_FILE $TMP_CERTFILE
   echo "$STR sudo cp $TARFILE $STUNNELDIR/. --"
   sudo cp $TARFILE $STUNNELDIR/.
   local CHECKTAR=`tar tvpfz $TARFILE`;
   print_info "$STR tar tvpfz $TARFILE : [$CHECKTAR] --"
   if [ "$CHECKTAR" != "" ]
    then
	# cleanup the temp files and keep only the tar file
	rm $CLIENTFILE $TMP_SERVICES $TMP_IPTABLE_CLN_RULE_FILE $TMP_HOSTS_ALLOW $CLN_CFG_FILE 
	echo "$STR sudo rm $TMP_CERTFILE -- --"
	sudo rm $TMP_CERTFILE
   fi 
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

def_ssl_server_cfg()
{
  local STR=" -- def_ssl_server_cfg - "
  local LOGDIR="/var/log/stunnel"
  
  SRV_CFG_FILE=${SSL_SERVER_NAME}.cfg
  echo " sslVersion = all " > $SRV_CFG_FILE
  echo " options = NO_SSLv2 " >> $SRV_CFG_FILE
  echo " debug = 7 " >> $SRV_CFG_FILE
  # this log file is only used if stunnel is started in daemon mode
  echo " output = $LOGDIR/${SSL_SERVER_NAME}.log " >> $SRV_CFG_FILE
  # create this directory in case it does not exist
  if [ ! -d $LOGDIR ]
   then
    echo "$STR sudo mkdir $LOGDIR --"
    sudo mkdir $LOGDIR
  fi
  get_redhat_version
  if [ "$RHVERSION"  == "7" ]
   then
############################################################################
#  The stunnel version delivered by default in RHEL-7 (stunnel 4.29 on x86_64-redhat-linux-gnu with OpenSSL 1.0.1e-fips) has a bug (REDHAT BUGZILLA #1498051 ; https://bugzilla.redhat.com/show_bug.cgi?id=1490851 ).  To circumvent this problem on RHEL-7, add the “tips = no” parameter to the stunnel config file, in order to be able to start it up in daemon mode. The “fips = no” parameter should be inserted before the stunnel-server/client definition in its config file
############################################################################
  	echo " fips = no " >> $SRV_CFG_FILE
  fi
  if [ "$DAEMONMODE" != "0" ]
    then
        echo " [$SSL_SERVER_NAME] " >> $SRV_CFG_FILE
  fi
  echo " client = no " >> $SRV_CFG_FILE
  if [ "$RHVERSION" != "6" ]
    then
	# The stunnel which is delivered in RHEL-6 does mnt
	# recognize the libwrap option
	echo " libwrap = yes " >> $SRV_CFG_FILE
  fi
  if [ $IPVERSION -eq 6 ]
   then
        echo " accept = :::$SSL_SERVER_PORT " >> $SRV_CFG_FILE
   elif [ $IPVERSION -eq 4 ]
    then
        echo " accept = 0.0.0.0:$SSL_SERVER_PORT " >> $SRV_CFG_FILE
  fi
  echo " connect = $OSC_PORT " >> $SRV_CFG_FILE
  echo " cert = ${STUNNELDIR}/${CERTNAME}" >> $SRV_CFG_FILE

  # save the file to the STUNNELDIR on the server hosts
  echo "$STR sudo cp $SRV_CFG_FILE ${STUNNELDIR}/. --"
  sudo cp $SRV_CFG_FILE ${STUNNELDIR}/.
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

def_ssl_client_cfg()
{
  local STR=" -- def_ssl_client_cfg - "
  local LOGDIR="/var/log/stunnel"
    
  CLN_CFG_FILE=${SSL_CLIENT_NAME}.cfg
  echo " sslVersion = all " > $CLN_CFG_FILE
  echo " options = NO_SSLv2 " >> $CLN_CFG_FILE
  echo " debug = 7 " >> $CLN_CFG_FILE
  # this log file is only used if stunnel is started in daemon mode
  echo " output = $LOGDIR/${SSL_CLIENT_NAME}.log " >> $CLN_CFG_FILE
  get_redhat_version
  if [ "$RHVERSION"  == "7" ]
   then
        # stunnel has a bug and we need to setup fips to NO in RHEL-7
        echo " fips = no " >> $CLN_CFG_FILE
  fi
  if [ "$DAEMONMODE" != "0" ]
    then
        echo " [$SSL_CLIENT_NAME] " >> $CLN_CFG_FILE
  fi
  echo " client = yes " >> $CLN_CFG_FILE
  if [ "$RHVERSION" != "6" ]
    then
        # The stunnel which is delivered in RHEL-6 does mnt
        # recognize the libwrap option
        echo " libwrap = yes " >> $CLN_CFG_FILE
  fi
  if [ $IPVERSION -eq 6 ]
   then
        echo " accept = localhost6:$REMOTEPORT " >> $CLN_CFG_FILE
	echo " connect = ${SSL_SERVER_HOST}:${SSL_SERVER_PORT} " >> $CLN_CFG_FILE
   elif [ $IPVERSION -eq 4 ]
    then
        echo " accept = localhost4:$REMOTEPORT " >> $CLN_CFG_FILE
	echo " connect = ${IPADDRESS}:${SSL_SERVER_PORT} " >> $CLN_CFG_FILE
  fi
  echo " cert = ${STUNNELDIR}/${CERTNAME}" >> $CLN_CFG_FILE

  # save the file to the STUNNELDIR on the server hosts
  # later it should be distributed to the client hosts
  print_info "|------------------- $STR end  -------------------------------------------------|"
}

start_stunnel_daemon()
{
   local STR=" -- start_stunnel_daemon - "
   local WRAPPER=`sudo which stunnel`
   if [ -z $WRAPPER ]
    then
     echo "$STR stunnel binary could not be found -- "
    else
      echo "$STR $WRAPPER sudo stunnel $SRV_CFG_FILE  --"
      sudo $WRAPPER $SRV_CFG_FILE &
      echo "$STR List of stunnel processes running --"
      sleep 0.6
      ps -ef | grep stunnel 
   fi
   print_info "|------------------- $STR end  -------------------------------------------------|"
}

###### main procedure ######

echo " == NOTE: this script can be used ONLY on VOD-9.0 versions == "
echo " == This shell is used to setup the stunnel server and later =="
echo " == the correspondent stunnel clients  =="
echo " == These stunnel wrappers will be named using the following patterns: =="
echo " == Server: ssl_srv_<serverHostname> ==" 
echo " == Client: ssl_cln_<serverHostname> =="  
echo " == VERY IMPORTANT  =="
echo " == The VERSANT_SERVICE_NAME variable should be defined OR =="
echo " == you should be using the default oscssd Versant service =="
echo; echo

  INFOLEVEL=1
  # Info level = 0 -> few debug information is printed
  # Info level != 0 -> more debug information is printed

  PRSTR="  == main - "

 LOCALDIR=`pwd`;
 STUNNELDIR="/etc/stunnel"
 SSL_SERVER_HOST=`hostname `;
 stopIF_hostname_null $SSL_SERVER_HOST

 echo "$PRSTR This machine: $SSL_SERVER_HOST will be setup as the stunnel server --"
 echo; echo

get_osc_service_def 
  echo "$PRSTR The OSC_NAME=$OSC_NAME is active and listenning to OSC_PORT=$OSC_PORT --"
  echo "$PRSTR The OSC_NAME=$OSC_NAME uses an IPv${IPVERSION} socket --"

  #  get the entries of the server ssl_service
  RESULT="TRUE"
  while [ "$RESULT" == "TRUE" ]
   do
     echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
     echo -n "$PRSTR Please, enter a valid port number for the SSL server:"
     read SSL_SERVER_PORT
     get_ssl_service_def  $SSL_SERVER_PORT $SSL_SERVER_HOST ;
   done

     # print_info "$PRSTR Result = $RESULT - the $SSLPORT port is available to the  $SSL_SERVER_NAME service --"
     echo "$PRSTR Result = $RESULT - the $SSL_SERVER_PORT port is available to the  $SSL_SERVER_NAME service --"
     echo "$PRSTR SSL client name:  $SSL_CLIENT_NAME should be set using IPv${IPVERSION} --"

 # Identify if the client port number is available at least
 # in one of the remote client hosts
  check_one_client 

 # Later I can add an option to skip the self signed certificate, but then
 # the customer would go for a CA certificate
 # generate a self signed certificate and save it into the /etc/stunnel directory
   self_signed_certificate $SSL_SERVER_HOST

  set_hosts_allow
  set_services
  set_iptable_rule

 # define if the stunnel will be started in daemon mode or by xinetd 
 # setting daemonMode to zero, then stunnel will be started by xinetd
 # any other value will make stunnel be started in daemon mode 
  DAEMONMODE="1"
  def_ssl_server_cfg
  def_ssl_client_cfg

  if [ "$DAEMONMODE" != "0" ]
   then
	start_stunnel_daemon
   else
	echo "$PRSTR starting stunnel by xinetd wasn't implemented! --"
  fi

 # save the client files
 pack_all_client_config_files

 print_info "$PRSTR END ==================================================="


