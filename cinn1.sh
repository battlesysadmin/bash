#!/bin/bash
# november  2013 * lg
#
# cinn1.sh * first script to run for recobbler and kernel upgrade of ddeb-mongo
# REQUIRES: /root/cinnamon directory
#

if [ "$USER" != "root" ]; then
     echo "please run as root" 
     exit
fi

echo "prep work: clean puppet cert; transfer cinnamon"

if [ -d /root/cinnamon ]; then
     cd /root/cinnamon
else 
     echo "you need cinnamon"
     exit
fi 

# original source for patched kernel from Canonical
#echo "downloading and installing kernel packages from Canonical engineer"
#wget http://people.canonical.com/~lbouchard/lp1233175/linux-headers-3.2.0-55-generic_3.2.0-55.84~lp1233175v201310021603_amd64.deb
#wget http://people.canonical.com/~lbouchard/lp1233175/linux-headers-3.2.0-55_3.2.0-55.84~lp1233175v201310021603_all.deb
#wget http://people.canonical.com/~lbouchard/lp1233175/linux-image-3.2.0-55-generic_3.2.0-55.84~lp1233175v201310021603_amd64.deb

dpkg --install ./linux-headers-3.2.0-55-generic_3.2.0-55.84~lp1233175v201310021603_amd64.deb ./linux-headers-3.2.0-55_3.2.0-55.84~lp1233175v201310021603_all.deb ./linux-image-3.2.0-55-generic_3.2.0-55.84~lp1233175v201310021603_amd64.deb ./linux-image-3.2.0-55-generic-dbgsym_3.2.0-55.85_amd64.ddeb

echo "updating menu timeout to allow time for kernel rollback"
sed -i -e s/GRUB_TIMEOUT=10/GRUB_TIMEOUT=60/ /etc/default/grub

update-grub

apt-get -y remove linux-headers-3.2.0-56 linux-headers-3.2.0-56-generic
rm -rf /boot/*56*

if [ !-e /boot/vmlinuz-3.2.0-55-generic ]; then
  echo "*******************************"
  echo "  CHECK KERNEL! CHECK KERNEL!  "
  echo "*******************************"
  exit
fi

update-grub

echo "switching repo to internal snapshot"
mv /etc/apt/sources.list /etc/apt/sources.list.orig

cat<<EOF >/etc/apt/sources.list
deb http://infra-repo-ubuntu.compliant.disney.private/2013_10_01/ubuntu precise main restricted universe multiverse
deb http://infra-repo-ubuntu.compliant.disney.private/2013_10_01/ubuntu precise-security main restricted universe multiverse
deb http://infra-repo-ubuntu.compliant.disney.private/2013_10_01/ubuntu precise-updates main restricted universe multiverse
deb http://infra-repo-ubuntu.compliant.disney.private/disney precise main contrib non-free
deb http://infra-repo-ubuntu.compliant.disney.private/disney02 precise main contrib non-free

EOF

/usr/bin/wget -O - http://infra-repo-ubuntu.compliant.disney.private/di.gpg.key | apt-key add -

apt-get update
apt-get -y upgrade

apt-get -y install linux-crashdump 

sed -i.backup -e 's/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT="\1 ipv6.disable=1 noapic acpi=noirq ehci_hcd=off intel_idle.max_cstate=0 processor.max_cstate=0"/' /etc/default/grub

update-grub

echo " "
echo " "
echo "installing Fusion IO software => watch carefully => if this step fails, you must install manually"
echo " "
echo " "
apt-get install -y iomemory-vsl-3.2.0-55-generic=3.2.2.869-1.0
apt-get install -y fio-common fio-sysvinit fio-firmware libvsl

echo " "
echo "***SETTING UP TO REBOOT...***"
echo " "

mkdir -p /var/lib/mongodb

echo " "
echo "***you have 30 seconds to ctrl-c before shutdown***"
echo " "

sleep 30

if [ -e /root/cinnamon/.cinn1 ]; then
   touch /root/cinnamon/.cinn1.`date +"%r"`
else
   touch /root/cinnamon/.cinn1
fi

shutdown -r now

