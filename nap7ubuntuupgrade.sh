#!/bin/bash

echo "Removing old package versions of "
echo "/etc/init/network-interface-security.conf.dpkg-dist "
echo "and "
echo "/etc/init.d/tomcat6.dpkg-dist"
echo "and"
echo "/etc/bash_completion.dpkg-dist"
echo "to make it easier to determine that we ended up with "
echo "\"older\" revision being left in place during next upgrade steps"

test -f /etc/init/network-interface-security.conf.dpkg-dist && rm /etc/init/network-interface-security.conf.dpkg-dist
test -f /etc/init.d/tomcat6.dpkg-dist && rm /etc/init.d/tomcat6.dpkg-dist
test -f /etc/bash_completion.dpkg-dist && rm /etc/bash_completion.dpkg-dist

addgroup whoopsie

puppet agent --disable

/etc/init.d/puppet stop
/etc/init.d/pe-puppet-agent stop
/etc/init.d/monit stop
/etc/init.d/pe-mcollective stop

touch /etc/init.d/ondemand

killall -KILL puppet
killall -TERM dpkg
killall -TERM apt-get

echo "Please wait, stopping tomcat6, nginx and php5-fpm services"

for ACTIVE_FILE in `find /var/lib/tomcat6/webapps -type f -name _ACTIVE`; do ACTIVE_DIR=`dirname ${ACTIVE_FILE}`; mv ${ACTIVE_FILE} ${ACTIVE_DIR}/UPGRADE_IN_PROGRESS; done

/bin/sleep 16 && service tomcat6 stop;service nginx stop;service php5-fpm stop

echo "Please wait, stopping Mongo services"

if [ -x /home/mlondarenko/mongosaferestart.pl ]; then
        /home/mlondarenko/mongosaferestart.pl --verbose --stop
elif [ -x /home/mlondarenko/cloudservices/mongosaferestart.pl ]; then
        /home/mlondarenko/cloudservices/mongosaferestart.pl --verbose --stop
elif [ -x ./mongosaferestart.pl ]; then
        ./mongosaferestart.pl --verbose --stop
else
        for MONGO_SERVICE in `find /etc/init/mongo*`;  do service  `echo ${MONGO_SERVICE} | sed -e 's#/etc/init/##g' -e 's#.conf##g'` stop; done
fi

/bin/sleep 16

killall --regexp "tail"

cat>/usr/sbin/policy-rc.d<<POLICYRCD
#!/bin/sh

if test x\${1} = "xtomcat6" -a x\${2} = "xstart"; then
	exit 101
fi
POLICYRCD

chmod +x /usr/sbin/policy-rc.d

#
# The process of removing old kernels is repeated again later one, since as part of updates/upgrades we end up with "new" old kernels
# being installed that take up the limited disk space in /boot filesystem.
#
for OLD_KERNEL in `dpkg --list|grep linux-image-2.6.32|/usr/bin/awk '{print $2;}'` ; do apt-get -y remove ${OLD_KERNEL}; done
for OLD_KERNEL in `dpkg --list|grep linux-image-2.6.38|/usr/bin/awk '{print $2;}'` ; do apt-get -y remove ${OLD_KERNEL}; done

/usr/sbin/update-grub2

apt-get -y remove ntp php5-mysql
groupadd messagebus

chattr -i /etc/apt/sources.list

cat>/etc/apt/sources.list<<NAP7MIRROR
deb http://infra-repo-ubuntu.general.disney.private/2014_01_01/ubuntu precise main restricted universe multiverse
deb http://infra-repo-ubuntu.general.disney.private/2014_01_01/ubuntu precise-security main restricted universe multiverse
deb http://infra-repo-ubuntu.general.disney.private/2014_01_01/ubuntu precise-updates main restricted universe multiverse

deb http://infra-repo-ubuntu.general.disney.private/2014_01_01/disney precise main contrib non-free
deb http://infra-repo-ubuntu.general.disney.private/2014_01_01/disney02 precise main contrib non-free
NAP7MIRROR

echo "Making sure puppet will not step on our toes during upgrade."
echo "Setting immutable attribute on /etc/apt/sources.list file."
/bin/sleep 5
chattr +i /etc/apt/sources.list

echo "ATTENTION HUMAN OPERATOR"
echo "We're about to issue apt-get upgrade command here. This output is just for troubleshooting purposes."

apt-get clean all
apt-get -o APT::Cache-Limit=100000000 -y update --fix-missing || exit
apt-get -y -o Dpkg::Options::="--force-confold" install nscd
apt-get -y autoremove
UCF_FORCE_CONFFOLD=yes apt-get -y -o Dpkg::Options::="--force-confold" install tomcat6
apt-get -y upgrade -o APT::Cache-Limit=100000000  || exit
apt-get -y autoremove

echo "About to install update-manager-core"

apt-get -y -o APT::Cache-Limit=100000000 -o APT::Immediate-Configure=false install python-gnupginterface update-manager-core ifupdown libdpkg-perl tzdata libuuid1 dbus || exit

groupadd ntp
apt-get -y -o Dpkg::Options::="--force-confold" install ntp

/bin/sleep 12

ntpq -c peers

/etc/init.d/puppet stop
/etc/init.d/pe-puppet-agent stop
/etc/init.d/monit stop
/etc/init.d/pe-mcollective stop
killall -KILL puppet
killall -TERM dpkg
killall -TERM apt-get

chmod 775 /var/run/screen

chattr -i /etc/apt/sources.list

#
# This is the repeat of the old kernel removal step, since as part of updates/upgrades we end up with "new" old kernels
# being installed that take up the limited disk space in /boot filesystem.
#
for OLD_KERNEL in `dpkg --list|grep linux-image-2.6.32|/usr/bin/awk '{print $2;}'` ; do apt-get -y remove ${OLD_KERNEL}; done
for OLD_KERNEL in `dpkg --list|grep linux-image-2.6.38|/usr/bin/awk '{print $2;}'` ; do apt-get -y remove ${OLD_KERNEL}; done

echo "ATTENTION HUMAN OPERATOR"
echo "We're about to issue do-release-upgrade command here. This output is just for troubleshooting purposes."

do-release-upgrade --mode=server --quiet -f DistUpgradeViewNonInteractive

# IF wrong script left in place during ifupdown upgrade:
#
test -f /etc/init/network-interface-security.conf.dpkg-dist && cp -a /etc/init/network-interface-security.conf.dpkg-dist /etc/init/network-interface-security.conf

echo "Stopping tomcat6 again (in case it's running post upgrade), before re-enabling health check _ACTIVE file"
service tomcat6 stop

rm /usr/sbin/policy-rc.d

for ACTIVE_FILE in `find /var/lib/tomcat6/webapps -type f -name UPGRADE_IN_PROGRESS `; do ACTIVE_DIR=`dirname ${ACTIVE_FILE}`; mv ${ACTIVE_FILE} ${ACTIVE_DIR}/_ACTIVE; done

# IF wrong script left in place during tomcat6 upgrade:
#
test -f /etc/init.d/tomcat6.dpkg-dist && cp -a /etc/init.d/tomcat6.dpkg-dist /etc/init.d/tomcat6 && rm /etc/init.d/tomcat6.dpkg-dist

# IF wrong script left in place during bash-completion upgrade:
#
test -f /etc/bash_completion.dpkg-dist && cp -a /etc/bash_completion.dpkg-dist /etc/bash_completion && rm /etc/bash_completion.dpkg-dist

/usr/sbin/update-grub2

apt-get -y purge esound-common oss-compat
rm /etc/modprobe.d/blacklist-framebuffer.conf.dpkg-dist /usr/sbin/policy-rc.d

/usr/sbin/update-grub2