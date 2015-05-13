#/bin/bas`h
# november 2013 * lg
#
# cinn3.sh * third script to run for recobbler and kernel upgrade of ddeb-mongo
# REQUIRES: /root/cinnamon directory
#
# original script by Mike Londarenko

if [[ -d /root/cinnamon && -e /root/cinnamon/.cinn2 ]]; then
   cd /root/cinnamon
else
   echo "i need cinnamon - have you run cinn2??  - exiting" 
   exit
fi

service tomcat6 stop
service ntp stop
/etc/init.d/php5-fpm stop
/etc/init.d/pe-puppet-agent stop
/etc/init.d/pe-mcollective stop

apt-get clean all && apt-get update

apt-get -y purge php5-mongo php5 php5-cli php5-cgi php5-fpm php5-curl php5-dev

apt-get remove -y apache2-mpm-prefork apache2-mpm-worker apache2-mpm-itk php5-fpm
apt-get remove -y apache2.2-common apache2.2-bin

export DEBIAN_FRONTEND=noninteractive
apt-get install -q -y numactl whois ntp postfix csh tcsh zsh tshark wireshark bc curl sysstat dstat gcc djbdns daemontools pigz itop nfs-common

# NEED TO CHECK VERSION INSTEAD
#dpkg --list | grep vim
#if [ $? != 0 ]; then
#  apt-get -y install vim
#fi

dpkg --list | grep linux-crashdump
if [ $? != 0 ]; then
  apt-get -y install linux-crashdump
fi

apt-get purge -y daemontools-run

apt-get -y install php5-common php5-cli php5-cgi php5-curl

apt-get clean all && apt-get update

apt-get -y install php5-mongo

apt-get autoremove -y

apt-get -y remove ntp
userdel -r ntp

groupadd -g 53 Gdns
useradd -u 5353 -g 53 -d /etc/dnscache -M Gdnscache
useradd -u 5354 -g 53 -d /etc/dnscache -M Gdnslog

mkdir -p /root/bin
mkdir -p /var/lib/mongodb/TESTDATA

cat>/root/bin/mongoenvironmentcheck.sh<<MONGOENVIRONMENTCHECK
MONGOENVIRONMENTCHECK

chmod +x /root/bin/mongoenvironmentcheck.sh

sed -i '/debauto/d' /etc/hosts

apt-get clean all
apt-get update

echo Stopping MongoDB, stand by...

service mongodb stop

update-rc.d -f mongodb remove


# Fixing up the UID/GID mess

echo "Fixing up the UID/GID for mongodb to be consistent with the rest of systems"

sed -i '/mongodb/d' /etc/passwd
sed -i '/mongodb/d' /etc/group

pwconv 

groupadd -g 127 mongodb 

echo "mongodb:x:127:127:mongodb user account:/home/mongodb:/bin/false" >> /etc/passwd

pwconv

chown -R mongodb:mongodb /var/log/mong* /var/lib/mong*

sed -i 's/messagebus:x:[0-9][0-9][0-9]/messagebus:x:999/g' /etc/passwd

pwconv

apt-get install ntp
mkdir -p /var/log/ntp /var/lib/ntp/stats
touch /var/log/ntp.log

chown -R ntp:ntp /var/lib/ntp /var/log/ntpstats /var/log/ntp /var/log/ntp.log && service ntp restart && sleep 9 && ntpq -c peers

apt-get autoremove -y

service ntp start

# Last, but not least. Make sure VM zone reclamation is turned off (critically important on NUMA systems where we run MongoDB!)
cat>/etc/sysctl.d/30-vm-zone-reclaim-mode.conf<<ZONE_RECLAIM
#
# On every NUMA system where we run MongoDB we have to disable virtual memory zone reclamation
# under Linux kernel because of the fact that MongoDB typically mmap() all files into memory
# that it ever "needed" including the files that don't change often.
# With zone reclamation turned on the end result is that the moment a node runs out of memory
# it would attempt to dump the pages to disk instead of requesting some from neighboring node.
# This is the most likely reason for the mongod occassionally hanging for up to 2 minutes
# since it's a single threaded process and the moment it tries to allocate memory that the node
# can not fulfill - zone reclamation kicks in and the process is paused entirely.
# Here is a sample message:
# Jul 30 20:53:28 cloud-mongo93 kernel: [2598509.823662] INFO: task mongod:16884 blocked for more than 120 seconds.
# Jul 30 20:53:28 cloud-mongo93 kernel: [2598509.863797] "echo 0 > /proc/sys/kernel/hung_task_timeout_secs" disables this message.
#
vm.zone_reclaim_mode = 0
ZONE_RECLAIM

cat>/etc/sysctl.d/30-tcp-keepalive-5min.conf<<TCP_KEEPALIVE
#
# Set TCP keepalives to be more frequent. An apparent necessity to avoid a lot of
# socket exceptions caused by old connections being dropped when running MongoDB
#
net.ipv4.tcp_keepalive_time = 300
TCP_KEEPALIVE

# Set the MAX PID limit higher than default 32768

cat>/etc/sysctl.d/30-kernel-max-pid.conf<<KERNEL_MAX_PID
#
# We kept running into odd problem where it seemed that we're running out of memory on our
# Replica Set Cluster 99 (cloud-mongoh991/992/993). We couldn't figure out what was happening
# until I finally found the culprit - the kernel MAX PID limit is set to 32768 by default!
# This is the reason why at some point in time no new processes could be spawned
# and MongoDB couldn't handle new incoming connections either.
# Here is a status snapshot from one of the machines minutes before it starts refusing any new
# connections
# and spawning any new processes (you can't even use shell at that point)
#
# [root@cloud-mongoh992:/etc/init 16:17:43]# sysctl -a |grep pid_max
# kernel.pid_max = 32768
#
# [root@cloud-mongoh992:/proc/sys/kernel 16:18:30]# ps -eLf |wc -l
# 27097
#
# And here is an actual error we would be seeing in MongoDB logs when it happens
#
#Wed Nov 23 15:20:02 [initandlisten] connection accepted from 10.4.7.130:44457 #37947
#Wed Nov 23 15:20:02 [initandlisten] pthread_create failed: errno:11 Resource temporarily unavailable
#Wed Nov 23 15:20:02 [initandlisten] can't create new thread, closing connection
#Wed Nov 23 15:20:02 [initandlisten] connection accepted from 10.4.7.130:44458 #37948
#Wed Nov 23 15:20:02 [initandlisten] pthread_create failed: errno:11 Resource temporarily unavailable
#Wed Nov 23 15:20:02 [initandlisten] can't create new thread, closing connection
#Wed Nov 23 15:20:02 [initandlisten] connection accepted from 10.7.34.114:49547 #37949
#Wed Nov 23 15:20:02 [initandlisten] pthread_create failed: errno:11 Resource temporarily unavailable
#Wed Nov 23 15:20:02 [initandlisten] can't create new thread, closing connection
#Wed Nov 23 15:20:02 [initandlisten] connection accepted from 10.7.34.114:49548 #37950
#Wed Nov 23 15:20:02 [initandlisten] pthread_create failed: errno:11 Resource temporarily unavailable
#Wed Nov 23 15:20:02 [initandlisten] can't create new thread, closing connection
#Wed Nov 23 15:20:02 [initandlisten] connection accepted from 10.7.34.114:49549 #37951
#Wed Nov 23 15:20:02 [initandlisten] pthread_create failed: errno:11 Resource temporarily unavailable
#Wed Nov 23 15:20:02 [initandlisten] can't create new thread, closing connection
#Wed Nov 23 15:22:55 [initandlisten] connection accepted from 10.36.164.10:46801 #37952
#
#
kernel.pid_max=65536
KERNEL_MAX_PID

cat>/etc/sysctl.d/30-kernel-random.conf<<KERNEL_RANDOM
#
# We're frequently running low on entropy, especially on any
# machines on API tiers (mostly due to nounce and other operations
# related to authentication), so we need to make sure we wake up the
# processes that refill the entropy sooner than the default 128 bits
# because at that point the refill rate does not keep-up with the demand
# Setting it to 768 bits in conjunction with running rngd produced an
# immediate boost in performance of almost 10% when tested on our machines
# in NAP7 environment. 
#
# See random(4) for more information.
#
# Date: December 14, 2011
#
kernel.random.write_wakeup_threshold=768
KERNEL_RANDOM

echo "sanity checking..."

# md5sums

if [ `md5sum /root/bin/mongoenvironmentcheck.sh | awk '{ print $1 }'` != 1557c5c8ca71704e5b690397383dc74d ]; then
   echo "FAIL - /root/bin/mongoenvironmentcheck.sh md5sum" >> sanity.check
else
   echo "PASS - /root/bin/mongoenvironmentcheck.sh md5sum" >> sanity.check
fi

if [ `md5sum /root/bin/mongod_bindip.sh | awk '{ print $1 }'` != 9c853e53944229f2ec270da8ef844b58 ]; then
   echo "FAIL - /root/bin/mongod_bindip.sh md5sum" >> sanity.check
else
   echo "PASS - /root/bin/mongod_bindip.sh md5sum" >> sanity.check
fi

#permissions

#if [ 

#packages

## MUST INSTALL VIM HERE BECAUSE MIKE"S SAUCE KILLS IT
apt-get -y install vim


which vim
if [ $? != 0 ]; then
   echo "FAIL - vim package installed `date +"%r"`" >> sanity.check
else
   echo "PASS - vim package installed `date +"%r"`" >> sanity.check 
fi

dpkg --list | grep linux-crashdump
if [ $? != 0 ]; then
   echo "FAIL - linux-crashdump installed `date +"%r"`" >> sanity.check
else
   echo "PASS - linux-crashdump installed `date +"%r"`" >> sanity.check
fi

dpkg --list | grep mongodb-10gen
if [ $? != 0 ]; then
   echo "FAIL - mongodb installed `date +"%r"`" >> sanity.check
else
   echo "PASS - mongodb installed `date +"%r"`" >> sanity.check
fi

if [ "`mongod --version | grep git | awk '{ print $7 }'`" != "d6764bf8dfe0685521b8bc7b98fd1fab8cfeb5ae" ]; then
   echo "FAIL - mongodb package version `date +"%r"`" >> sanity.check
else
   echo "PASS - mongodb package version `date +"%r"`" >> sanity.check
fi

if [ "`ls -l /root/ | grep bin | awk '{ print $1 }'`" == "drwx------" ]; then
    echo "PASS - /root/bin permissions `date +"%r"`" >> sanity.check
else
    echo "FAIL - /root/bin permissions `date +"%r"`" >> sanity.check
fi

if [ "`ls -l /root/bin/mongoenvironmentcheck.sh | awk '{ print $1 }'`" == "-rwxr-xr-x" ]; then
    echo "PASS - /root/bin/mongoenvironmentcheck.sh permissions `date +"%r"`" >> sanity.check
else
    echo "FAIL - /root/bin/mongoenvironmentcheck.sh permissions `date +"%r"`" >> sanity.check
fi

if [ -e /root/cinnamon/.cinn3 ]; then
   touch /root/cinnamon/.cinn3.`date +"%r"`
else
   touch /root/cinnamon/.cinn3
fi

echo "--------------------"
echo "SANITY CHECK RESULTS"
echo "--------------------"
cat ./sanity.check
echo "--------------------"
echo " "
echo "if all is well, you can now set up mongo, or, contact a DBA for help"
echo " ---> RUN securityUpgrades.pl (preferred), contact a DBA (preferred), OR" 
echo " 1. after mongdb pkg from 10gen is installed, remove the default /etc/init/mongodb.conf"
echo " 2. see if node directories are prestn in /var/lib/mongodb - of not recreate, copying from a replica set member"
echo " 3. verify that you have /root/bin/mongod_bindip.sh"
echo " 4. all of the /etc/init/mongodb* files from another replica set member"
echo " 5. copy all the /etc/<product_name>.conf files from another replica set member"
echo " ---> hint: use expressions "cloud*.conf" and "*_*.conf" to grab files"
echo " 6. start mongoes: for MONGO_SERVICE in `find /etc/init/mongo*`;  do service  `echo ${MONGO_SERVICE} | sed -e 's#/etc/init/##g' -e 's#.conf##g'` start; done"
echo " 7. monitor replica set for lag with delay.js"
echo " "
echo "**********************************"
echo "* please reboot now **************"
echo "**********************************"
echo " "

