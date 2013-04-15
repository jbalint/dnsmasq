#!/bin/bash
# VPN setup script for Oracle VPN
# Allows only oracle.com traffic to go through the VPN
set -e
set -x

# connect to the VPN, this will overwrite routing table and add a bunch of iptables rules
vpn connect myaccess.oraclevpn.com

# fix the routing table and clear out iptables
sudo iptables -F
sudo ip route del default
sudo ip route add default dev wlp3s0 via 192.168.1.1

# get the VPN ip (so dnsmasq can add the routes)
VPNIP=$(ip addr show dev cscotun0 | grep inet | perl -lpe's/.*inet (.*?)\/.*/$1/')
echo VPN IP $VPNIP

# get the nameserver IP and give a route to it
NSIP=$(cat /etc/resolv.conf | grep nameserver | head -1 | perl -lpe's/nameserver\s+//')
sudo ip route add $NSIP dev cscotun0 via $VPNIP
echo Nameserver $NSIP

# go to great lengths to rewrite resolv.conf
# the vpnagentd watches it with inotify and rewrites it immediately after I change it
# set inotify limit to 0, first rewrite, vpnagentd will fix it, but then wont be able to set the watch again....
INOTIFYLIMIT=`cat /proc/sys/fs/inotify/max_user_watches`
sudo bash -c "echo 0 > /proc/sys/fs/inotify/max_user_watches"
sudo bash -c "echo nameserver 127.0.0.1 > /etc/resolv.conf"
sleep 1
sudo bash -c "echo nameserver 127.0.0.1 > /etc/resolv.conf"
sudo bash -c "echo $INOTIFYLIMIT > /proc/sys/fs/inotify/max_user_watches"

# switch over to the dnsmasq
sudo VPNIP=$VPNIP src/dnsmasq -o --server=192.168.1.1 \
    --server=/oracle.com/oraclecorp.com/sun.com/java.net/$NSIP \
    --log-facility=- --no-daemon --log-queries --no-resolv #--domain-needed
