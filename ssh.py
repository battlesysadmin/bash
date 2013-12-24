#!/usr/bin/python
#
# lois and alexis * December 2013
#
# depends:
# paramiko for ssh
# os for os stuff
#
# replace USER and PASSWORD with real values

import paramiko
import os

f = open("hostname_list", "r")

for line in f:
    print "checking this line: %s" % line
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(line.strip(),username='USER',password='PASSWORD')
    stdin, stdout, stderr = ssh.exec_command("hostname")
    print stdout.read()