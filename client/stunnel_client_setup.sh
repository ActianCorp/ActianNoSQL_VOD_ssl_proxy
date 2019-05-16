#!/bin/bash 

##################################################################### 
#
# initial version: Apr 2019 - Alberico Perrella Neto
#####################################################################

#  NOTE: this script can be used ONLY on VOD-9.0 versions 
#  This shell script is used to setup the stunnel client 
#  the TARFILE (client_conf_SSL_SERVER_NAME.tgz) file should 
#  be copied to this client machine and be passed as the 
#  onöy argument
#  The stunnel wrappers are named using the following patterns:
#  Server: ssl_srv_<serverHostname> 
#  Client: ssl_cln_<serverHostname> 


print_info()
{
  local INFO=$1

  if [ "$INFOLEVEL" != "0" ]
   then
     echo $INFO
  fi
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
	echo -n "$STR Please enter the domain name of this network (example: versant.com): "  
	read DOMAIN
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
  print_info "$STR end -------------------------------------------------|"
}

check_socket()
{
   # this function should set the socket to NULL if
   # the passed port does not match the port assigned to
   # this socket

   local STR=" -- check_socket - "
   SOCKET=$1
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
 print_info "$STR end -------------------------------------------------|"
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
 print_info "$STR end -------------------------------------------------|"
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
  print_info "$STR end -------------------------------------------------|"
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
  
  SSLPORT=$1
  THISHOST=$2

  echo "$STR ServicePort = $SSLPORT - Target = $THISHOST --"

  # I need to setup the name of the SSL_service before start to verify
  # if its name and port numbers are available   

	SERVICENAME="ssl_srv_${THISHOST}"
	echo "$STR (server) ServiceName = $SERVICENAME --"
	search_ssl $SERVICENAME $SSLPORT;

 # This should be veriufied later on the client machines
	CLIENTNAME="ssl_cln_${THISHOST}"
	echo "$STR (client) ServiceName = $CLIENTNAME --"

  print_info "$STR end -------------------------------------------------|"
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
     echo $LINE |sudo tee -a $TARGETFILE
    done
  print_info "$STR end -------------------------------------------------|"
}

set_hosts_allow()
{
   local HOSTS_ALLOW_FILE="/etc/hosts.allow"
   local MTMP_HOSTS_ALLOW=$1
    # Now that we have a temporary file, add these entries to
    # the /etc/hosts.allow file
    add_entries $MTMP_HOSTS_ALLOW $HOSTS_ALLOW_FILE
}

set_iptable_rule()
{
  local STR=" -- set_iptable_rule - "

  local MTMP_IPTABLE_CLN_RULE_FILE=$1
  local RULE=`cat $MTMP_IPTABLE_CLN_RULE_FILE`;
   sudo  $RULE
  print_info "$STR end -------------------------------------------------|"
}

set_services()
{  
   local SERVICES_FILE="/etc/services" 
   local MTMP_SERVICES=$1

    # Now that we have a temporary file, add these entries 
    # to the /etc/services file of the server host
    # Notice that the osc* service is already defined 
    # and active on the server host
    add_entries $MTMP_SERVICES $SERVICES_FILE

  print_info "$STR end -------------------------------------------------|"
}

start_stunnel_daemon()
{
   local STR=" -- start_stunnel_daemon - "
   local CFG_FILE=$1

   local WRAPPER=`which stunnel`;
   if [ -z $WRAPPER ]
    then
     echo "$STR stunnel binary could not be found -- "
    else
      echo "$WRAPPER sudo stunnel $CFG_FILE  --"
      sudo $WRAPPER $CFG_FILE &
      echo "$STR List of stunnel processes running --"
      ps -ef | grep stunnel
   fi
   print_info "$STR end -------------------------------------------------|"
}

prepare_client()
{
  local STR=" -- prepare_client - "
  echo "$STR TMP_HOSTS_ALLOW = $TMP_HOSTS_ALLOW ; CLN_CFG_FILE = $CLN_CFG_FILE -"
  return  10;
  set_hosts_allow $TMP_HOSTS_ALLOW
  set_services $TMP_SERVICES
  set_iptable_rule $TMP_IPTABLE_CLN_RULE_FILE

  if [ "$DAEMONMODE" != "0" ]
   then
	start_stunnel_daemon $CLN_CFG_FILE
   else
	echo "$STR starting stunnel by xinetd wasn't implemented! --"
  fi
}

setup_variables()
{
  local STR=" -- setup_variables - "
  VARNAME=$1
  VARVALUE=$2

     if [ "$VARNAME" == "VERSANT_SERVICE_NAME" ]
      then
        VERSANT_SERVICE_NAME=$VARVALUE
     elif [ "$VARNAME" == "STUNNELDIR" ]
      then
        STUNNELDIR=$VARVALUE
     elif [ "$VARNAME" == "TMP_SERVICES" ]
      then
        TMP_SERVICES=$VARVALUE
	#set_services $TMP_SERVICES
     elif [ "$VARNAME" == "TMP_IPTABLE_CLN_RULE_FILE" ]
      then
        TMP_IPTABLE_CLN_RULE_FILE=$VARVALUE
	#set_iptable_rule $TMP_IPTABLE_CLN_RULE_FILE
     elif [ "$VARNAME" == "TMP_HOSTS_ALLOW" ]
      then
        TMP_HOSTS_ALLOW=$VARVALUE
  	#set_hosts_allow $TMP_HOSTS_ALLOW
     elif [ "$VARNAME" == "CLN_CFG_FILE" ]
      then
        CLN_CFG_FILE=$VARVALUE
     elif [ "$VARNAME" == "CERTNAME" ]
      then
        CERTNAME=$VARVALUE
     elif [ "$VARNAME" == "DAEMONMODE" ]
      then
        DAEMONMODE=$VARVALUE
    fi
  print_info "$STR $VARNAME=$VARVALUE -"
  print_info "$STR ------------------------------"
}

read_file()
{
  local STR=" -- read_file - "
  local FILE=$1

  if [ ! -e $FILE ]
   then
        echo " [$FILE] does not exit! Exit now!"
        exit 1
  fi

  cat $FILE |\
   while read LINE
   do
    # LINE looks like: "<parameter> = <value>"
     local NAME=`echo $LINE | awk '{print $1}'`;
     local VALUE=`echo $LINE | awk '{print $3}'`;

    # setup the global variables according
    if [ ! -z  $NAME ]
     then
	print_info "$STR setup_variables $NAME $ALUE --"
	setup_variables $NAME $VALUE
    fi
   done
   print_info "$STR CERTNAME=$CERTNAME -"
}

test_print()
{
#  local LIST="DAEMONMODE CERTNAME CLN_CFG_FILE TMP_HOSTS_ALLOW TMP_IPTABLE_CLN_RULE_FILE TMP_SERVICES STUNNELDIR VERSANT_SERVICE_NAME"
 # for VAR in $LIST
 # do
   echo " --test_print - TMP_SERVICES = $TMP_SERVICES  "
 # done
}
###### main procedure ######


  INFOLEVEL=1
  # Info level = 0 -> few debug information is printed
  # Info level != 0 -> more debug information is printed

  export DAEMONMODE CERTNAME CLN_CFG_FILE TMP_HOSTS_ALLOW TMP_IPTABLE_CLN_RULE_FILE TMP_SERVICES STUNNELDIR VERSANT_SERVICE_NAME

  PRSTR="  == main - "

  if [ "$#" != "1" ]
   then
     echo "$PRSTR Usage: $0 client_conf_SERVICENAME.tgz =="
     echo "$PRSTR  Exiting now! =="
     exit 1
  fi


 TARFILE=$1

 LOCALDIR=`pwd`;
 AUX=${LOCALDIR}/tmp
 if [ ! -d $AUX ]
  then
	mkdir $AUX
  fi
 tar xvpfz $TARFILE -C $AUX 

 # verify if TARFILE contetnts were extracted before proceed
 if [ -z $AUX ]
   then
	echo "$PRSTR the $AUX directory is empty! =="  
	echo "$PRSTR Failed to untar $TARFILE! Exiting now! =="  
 	exit 1001
 fi

 if [ ! -e $AUX/client_config.txt ]
   then
	echo "$PRSTR  The client_config.txt file does not exit! Exiting now! =="  
	exit 1002
   else 
   
     echo "$PRSTR This machine will be setup as one remote stunnel client --"
     read_file ${AUX}/client_config.txt 

     # Need to get sure the cariables defined on the previous functions are passed to the next functions
     print_info "$PRSTR CERTNAME=$CERTNAME -"
     # prepare_client
 fi 

 print_info "$PRSTR END ==================================================="


