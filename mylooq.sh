#!/bin/bash
#
# alexis g. * february 2014
#
# alias to check mysql db hosts from nexus
# could be fluffed out to do more...


for host in `cat /etc/hosts | grep db | grep -v extern | awk '{ print $2 }'`; do echo -e "$host\t" ; for num in `seq 3300 3310`; do a=`nc $host $num -w 1` ; echo $a | grep 5 ; done ; done