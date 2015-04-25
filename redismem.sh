#!/bin/bash

# redismem.sh * 17 jun 2014 * lg
# get memory statistics on redis servers
# REQUIRES: smem

REDISMEM=`smem | grep redis-server | grep -v grep | awk '{ print $7 }'`
REDISES=`ps -ef | grep redis-server | grep -v grep | wc -l`
SUM=0
PORTS=`netstat -pn | grep EST | grep redis | awk '{ print $4 }' | awk -F":" '{ print $2 }' | sort | uniq`
GBFREE=`free -g | grep -v free | head -1 | awk '{ print $4 }'`
GBUSED=`free -g | grep -v free | head -1 | awk '{ print $3 }'`

for i in $REDISMEM; do SUM=$(($SUM + $i)); done

echo "======="
hostname --fqdn
echo "Redis instances: $REDISES"
echo "Redis instance total proportional set size in blocks: $SUM"
AVG=$(($SUM / $REDISES))
echo "Redis instance avg proportional set size in blocks: $AVG"
#echo "Redis is running on ports:"
#echo "$PORTS"
echo " "
echo "OS reported GB memory used: $GBUSED"
echo "OS reported GB memory free: $GBFREE"
echo " "
echo "Redis instance peak memory usage in GB as reported by redis-cli..."
for i in `netstat -pn | grep EST | grep redis | awk '{ print $4 }' | awk -F":" '{ print $2 }' | sort | uniq`; do echo "$i:"; redis-cli -p $i INFO | grep used_memory_peak_human; done

echo " "

echo "smem RSS and PSS report p/instance:"
smem -P redis-server -c "pid rss pss swap command" | grep -v smem
#smem -P redis-server | grep -v smem
echo " "
echo "ps RSS report p/instance:"
ps -o pid,rss,vsz,cmd -U redi
