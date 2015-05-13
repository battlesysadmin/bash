#!/bin/bash
# november 2013 * lg
#
# cinn2.sh * second script to run for recobbler and kernel upgrade of ddeb-mongo
# REQUIRES: /root/cinnamon directory
#

if [ "$USER" != "root" ]; then
   echo "please run as root" 
   exit
fi

if [[ -d /root/cinnamon && -e /root/cinnamon/.cinn1 ]]; then
   cd /root/cinnamon
else
   echo "i need cinnamon - have you run cinn1??  - exiting" 
   exit
fi

echo '/dev/fioa /var/lib/mongodb        ext4    errors=remount-ro,noatime,nodiratime       0       2'  >> /etc/fstab

mount -a
if [ $? != 0 ]; then
   echo "fio mount issue - do a graceful reboot of the server and try again"
   exit
fi 

touch /var/lib/mongodb/touch && ls -l /var/lib/mongodb
if [ /var/lib/mongodb/touch ]; then
    echo " "
    echo "mount is good"
    echo " "
    rm /var/lib/mongodb/touch
else
    echo " "
    echo "mount is bad -> SOMETHING IS WRONG" 
    echo " "
    exit
fi

echo "did you puppet-clean-cert from infra-bastion01? if not... you have 30 seconds to ctrl-c out and do the needful"
sleep 30

useradd pe-puppet
apt-get -y install pd-puppet-enterprise

grep `hostname --fqdn` /etc/puppetlabs/puppet/puppet.conf
if [ $? != 0 ]; then
  sed -i -e s/`hostname --short`/`hostname --fqdn`/ /etc/puppetlabs/puppet/puppet.conf
fi

echo " "
echo "look carefully at the puppet.conf and verify, or ctrl-c and fix"
echo " "
cat /etc/puppetlabs/puppet/puppet.conf
echo " "
sleep 45

puppet agent -vt | tee puppet.firstrun
puppet agent -vt | tee puppet.$$
puppet agent -vt | tee puppet.$$
puppet agent -vt | tee puppet.$$

if [ /home/lgarcia/.ssh ]; then
     cat /root/cinnamon/lois.pub >> /home/.ssh/authorized_keys 
   else mkdir -p /home/lgarcia/.ssh
     chown -R lgarcia: /home/lgarcia/.ssh
     cat /root/cinnamon/lois.pub >> /home/.ssh/authorized_keys
fi

echo "creating rc.local"

cat<<RC.LOCAL >/etc/rc.local
for INTERFACE in `seq 0 7`
do
    if [ -f /sys/class/net/eth${INTERFACE}/carrier ]; then 
         /sbin/ifconfig eth${INTERFACE} txqueuelen 8000 
    fi
done

echo Done tweaking txqueuelen on all the network interfaces we have found

exit 0
RC.LOCAL

chmod 555 /etc/rc.local

mkdir /root/bin
chmod 700 /root/bin

if [ -e /root/cinnamon/mongod_bindip.sh ]; then
   cp /root/cinnamon/mongod_bindip.sh /root/bin/
else
   echo "mongod_bindip.sh unavailable"
fi

if [ -e /root/bin/mongod_bindip.sh ]; then
   chmod 755 /root/bin/mongod_bindip.sh
else
   echo "/root/bin/mongod_bindip.sh is missing - FAIL" 
fi

echo " "
echo "installing the proper mongodb package"
echo " "
echo "if this fails, you must install manually"
echo " "

apt-get -y install mongodb-10gen=2.2.1
if [ $? != 0 ]; then
     echo "apt-get mongo install failed, trying local file" 
     if [ -e /root/cinnamon/mongodb-10gen_2.2.1_amd64.deb ]; then
         dpkg --install /root/cinnamon/mongodb-10gen_2.2.1_amd64.deb
     else
         echo "file mongodb-10gen_2.2.1_amd64.deb not found - FAIL" 
         echo "you must find a way to install mongodb-10gen v2.2.1"
     fi
else
  echo "mongo successfully installed via apt-get"
fi

if [ /etc/init/mongodb.conf ]; then
   rm /etc/init/mongodb.conf
fi

echo "kernel upgrade is done:"
echo " - reboot"
echo " - check mount of FusionIO drive (/var/lib/mongodb)"
echo " - run third cinn script"
echo " - complete mongo set up"

if [ -e /root/cinnamon/.cinn2 ]; then
   touch /root/cinnamon/.cinn2.`date +"%r"`
else
   touch /root/cinnamon/.cinn2
fi


exit 666

