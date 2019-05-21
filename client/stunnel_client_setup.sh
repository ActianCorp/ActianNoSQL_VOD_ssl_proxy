#!/bin/bash 

##################################################################### 
#
# initial version: May 2019 - Alberico Perrella Neto
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

set_services()
{  
   local SERVICES_FILE="/etc/services" 
   local MTMP_SERVICES=$1

    # Now that we have a temporary file, add these entries 
    # to the /etc/services file of the server host
    # verify if the osc* service is already defined 
    #  on the client host

    add_entries $MTMP_SERVICES $SERVICES_FILE

  print_info "$STR end -------------------------------------------------|"
}

set_iptable_rule()
{
  local STR=" -- set_iptable_rule - "

  local MTMP_IPTABLE_CLN_RULE_FILE=$1
  local RULE=`cat $MTMP_IPTABLE_CLN_RULE_FILE`;
   sudo  $RULE
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

function_setup()
{
  local MFUNCTION=$1
  local MFILE=$2

     if [ ! -z $MFILE ]
      then
	echo "$MFUNCTION $MFILE"
	$MFUNCTION $MFILE
      else
        echo " The $FUNCTION  could not br setup because the $MFILE is empty!"
        exit 2;
     fi
}

prepare_client()
{
  local STR=" -- prepare_client - "
  echo "$STR DAEMONMODE = $DAEMONMODE ;  CLN_CFG_FILE = $CLN_CFG_FILE -"
  return  10;

  if [ "$DAEMONMODE" != "0" ]
   then
	start_stunnel_daemon $CLN_CFG_FILE
   else
	echo "$STR starting stunnel by xinetd wasn't implemented! --"
  fi
}

###### main procedure ######


  INFOLEVEL=1
  # Info level = 0 -> few debug information is printed
  # Info level != 0 -> more debug information is printed

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
  FILE=${AUX}/client_config.txt 

	     VALUE=` grep VERSANT_SERVICE_NAME $FILE | awk '{ print $3 }'`;
	        VERSANT_SERVICE_NAME=$VALUE
	     VALUE=` grep STUNNELDIR $FILE | awk '{ print $3 }'`;
	        STUNNELDIR=$VALUE
	     VALUE=` grep TMP_SERVICES $FILE | awk '{ print $3 }'`;
	        TMP_SERVICES="$VALUE"
	     VALUE=` grep TMP_IPTABLE_CLN_RULE_FILE $FILE | awk '{ print $3 }'`;
		TMP_IPTABLE_CLN_RULE_FILE=$VALUE
	     VALUE=` grep TMP_HOSTS_ALLOW $FILE | awk '{ print $3 }'`;
	        TMP_HOSTS_ALLOW=$VALUE
	     VALUE=` grep CLN_CFG_FILE $FILE | awk '{ print $3 }'`;
	        CLN_CFG_FILE=$VALUE
	     VALUE=` grep CERTNAME $FILE | awk '{ print $3 }'`;
	        CERTNAME="$VALUE"
	     VALUE=` grep DAEMONMODE $FILE | awk '{ print $3 }'`;
	        DAEMONMODE=$VALUE

	function_setup set_services $AUX/$TMP_SERVICES

	function_setup set_hosts_allow $AUX/$TMP_HOSTS_ALLOW

	function_setup set_iptable_rule $AUX/$TMP_IPTABLE_CLN_RULE_FILE

#	prepare_client 

 fi  # end_else [ ! -e $AUX/client_config.txt ]

 print_info "$PRSTR END ==================================================="


