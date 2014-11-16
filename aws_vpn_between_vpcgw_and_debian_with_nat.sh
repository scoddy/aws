#!/bin/bash
#
# Setup VPN between Debian Linux and VPC G/W.
#   How to use : ./this_script.sh Generic.txt
#
# For connecting IPsec VPN, you need to allow these connections.
# If VPN has global address, you change FORWARD to OUTPUT.
#
#   ex) iptables -A FORWARD -p udp --dport 500 -j ACCEPT
#       iptables -A FORWARD -p tcp --dport 500 -j ACCEPT
#       iptables -A FORWARD -p esp -j ACCEPT
#
# Change to suit your environment iptables setting.
#
# After executing on VPN, set client routing.
#

PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

exitMessage() {
    echo "$@" >&2
    exit 1
}

[ `id -u` = 0 ] || exitMessage "Set user to root."


#
# Opetion
#

CONF=$1
[ -z "$CONF" -o ! -r "$CONF" ] && exitMessage "Input VPC+VPN Generic config."

#########
#
# Config
#

HOSTNAME=`hostname`
INTERFACE="eth0"

VPC_SUBNET="10.142.32.0/21"
QUAGGA_PASSWORD="QuaggaPassword"

CUSTOMER_SUBNET=`LANG=C ip addr show dev $INTERFACE \
              | grep -m1 "inet " | sed -e 's/^.*inet \([\.0-9\/]\+\) .*/\1/g'`
CUSTOMER_ADDR=`echo "$CUSTOMER_SUBNET" | cut -d/ -f1`

RACOON_LOG="/var/log/racoon/racoon.log"
BGPD_LOG="/var/log/quagga/bgpd.log"

#########
#
# Generic Config Values
#

CONNECTION_ID=`cat $CONF | grep "Your VPN Connection ID" | awk '{print $6}'`

T1_OUT_CUSTOMER_GW=`cat $CONF | grep -m1 "\- Customer Gateway"        | tail -1 | awk '{print $5}'`
T1_OUT_VPC_GW=`     cat $CONF | grep -m1 "\- Virtual Private Gateway" | tail -1 | awk '{print $6}'`
T1_IN_CUSTOMER_GW=` cat $CONF | grep -m2 "\- Customer Gateway"        | tail -1 | awk '{print $5}'`
T1_IN_VPC_GW=`      cat $CONF | grep -m2 "\- Virtual Private Gateway" | tail -1 | awk '{print $6}'`
T1_PSK=`            cat $CONF | grep -m1 "\- Pre-Shared Key"          | tail -1 | awk '{print $5}'`
T1_ASN=`            cat $CONF | grep -m1 "Private *Gateway ASN"       | tail -1 | awk '{print $7}'`
T1_NEIGHBOR_ADDR=`  cat $CONF | grep -m1 "Neighbor IP Address"        | tail -1 | awk '{print $6}'`

T2_OUT_CUSTOMER_GW=`cat $CONF | grep -m4 "\- Customer Gateway"        | tail -1 | awk '{print $5}'`
T2_OUT_VPC_GW=`     cat $CONF | grep -m3 "\- Virtual Private Gateway" | tail -1 | awk '{print $6}'`
T2_IN_CUSTOMER_GW=` cat $CONF | grep -m5 "\- Customer Gateway"        | tail -1 | awk '{print $5}'`
T2_IN_VPC_GW=`      cat $CONF | grep -m4 "\- Virtual Private Gateway" | tail -1 | awk '{print $6}'`
T2_PSK=`            cat $CONF | grep -m2 "\- Pre-Shared Key"          | tail -1 | awk '{print $5}'`
T2_ASN=`            cat $CONF | grep -m2 "Private *Gateway ASN"       | tail -1 | awk '{print $7}'`
T2_NEIGHBOR_ADDR=`  cat $CONF | grep -m2 "Neighbor IP Address"        | tail -1 | awk '{print $6}'`

VALUES="T1_OUT_CUSTOMER_GW T1_OUT_VPC_GW T1_IN_CUSTOMER_GW T1_IN_VPC_GW"
VALUES+=" T1_PSK T1_ASN T1_NEIGHBOR_ADDR"
VALUES+=" T2_OUT_CUSTOMER_GW T2_OUT_VPC_GW T2_IN_CUSTOMER_GW T2_IN_VPC_GW"
VALUES+=" T2_PSK T2_ASN T2_NEIGHBOR_ADDR"
for v in $VALUES
do
	[ -z `eval 'echo $'$v` ] && exitMessage "Colud not found $v from $CONF."
done

#########
#
# Package
#

apt-get -y install racoon ipsec-tools quagga

#########
#
# sysctl
#

cat << EOT > /etc/sysctl.d/vpn.conf
net.ipv4.ip_forward = 1

# prevent the panic of client, when switching vpn route.
net.ipv4.conf.all.send_redirects	= 0
net.ipv4.conf.default.send_redirects	= 0
net.ipv4.conf.eth0.send_redirects	= 0
net.ipv4.conf.lo.send_redirects		= 0

net.ipv4.conf.all.accept_redirects	= 0
net.ipv4.conf.default.accept_redirects	= 0
net.ipv4.conf.eth0.accept_redirects	= 0
net.ipv4.conf.lo.accept_redirects	= 0
EOT

service procps restart

#########
#
# iptables
#
#cat << EOT > /etc/iptables/conf.d/aws-vpc
##!/bin/bash

## AWS VPC
#iptables -t nat -A POSTROUTING -d $VPC_SUBNET -j MASQUERADE
#iptables -A FORWARD            -d $VPC_SUBNET -j ACCEPT
#EOT

#service iptables start

#
# Create Config File
#

## Pre-Shared Key ##

cat << EOT > /etc/racoon/aws-vpc.txt
$T1_OUT_VPC_GW $T1_PSK
$T2_OUT_VPC_GW $T2_PSK
EOT

chmod 600 /etc/racoon/aws-vpc.txt

#
# Racoon
#

mkdir /var/log/racoon

cat << EOT > /etc/racoon/racoon.conf
log notify;
path pre_shared_key "/etc/racoon/aws-vpc.txt";

remote $T1_OUT_VPC_GW {
	exchange_mode main;
	lifetime time 28800 seconds;
    dpd_delay = 10;
    dpd_retry = 3;
	proposal {
		encryption_algorithm aes128;
		hash_algorithm sha1;
		authentication_method pre_shared_key;
		dh_group 2;
	}
	generate_policy off;
}

remote $T2_OUT_VPC_GW {
	exchange_mode main;
	lifetime time 28800 seconds;
    dpd_delay = 10;
    dpd_retry = 3;
	proposal {
		encryption_algorithm aes128;
		hash_algorithm sha1;
		authentication_method pre_shared_key;
		dh_group 2;
	}
	generate_policy off;
}

sainfo address $T1_IN_CUSTOMER_GW any address $T1_IN_VPC_GW any {
	pfs_group 2;
	lifetime time 3600 seconds;
	encryption_algorithm aes128;
	authentication_algorithm hmac_sha1;
	compression_algorithm deflate;
}

sainfo address $T2_IN_CUSTOMER_GW any address $T2_IN_VPC_GW any {
	pfs_group 2;
	lifetime time 3600 seconds;
	encryption_algorithm aes128;
	authentication_algorithm hmac_sha1;
	compression_algorithm deflate;
}
EOT

#
# Setkey
#

cat << EOT > /etc/ipsec-tools.d/vpc.conf
#!/usr/sbin/setkey -f

flush;
spdflush;

# Tunnel1 Transfer Net
spdadd $T1_IN_CUSTOMER_GW $T1_IN_VPC_GW any -P out ipsec esp/tunnel/$CUSTOMER_ADDR-$T1_OUT_VPC_GW/require;
spdadd $T1_IN_VPC_GW $T1_IN_CUSTOMER_GW any -P in  ipsec esp/tunnel/$T1_OUT_VPC_GW-$CUSTOMER_ADDR/require;

# Tunnel1 VPC right
spdadd $T1_IN_CUSTOMER_GW $VPC_SUBNET   any -P out ipsec esp/tunnel/$CUSTOMER_ADDR-$T1_OUT_VPC_GW/require;
spdadd $VPC_SUBNET $T1_IN_CUSTOMER_GW   any -P in  ipsec esp/tunnel/$T1_OUT_VPC_GW-$CUSTOMER_ADDR/require;

# Tunnel2 Transfer Net
spdadd $T2_IN_CUSTOMER_GW $T2_IN_VPC_GW any -P out ipsec esp/tunnel/$CUSTOMER_ADDR-$T2_OUT_VPC_GW/require;
spdadd $T2_IN_VPC_GW $T2_IN_CUSTOMER_GW any -P in  ipsec esp/tunnel/$T2_OUT_VPC_GW-$CUSTOMER_ADDR/require;

# Tunnel2 VPC right
spdadd $T2_IN_CUSTOMER_GW $VPC_SUBNET   any -P out ipsec esp/tunnel/$CUSTOMER_ADDR-$T2_OUT_VPC_GW/require;
spdadd $VPC_SUBNET $T2_IN_CUSTOMER_GW   any -P in  ipsec esp/tunnel/$T2_OUT_VPC_GW-$CUSTOMER_ADDR/require;
EOT

#
# bgpd
#

cat << EOT > /etc/quagga/bgpd.conf
hostname $HOSTNAME
password $QUAGGA_PASSWORD
enable password $QUAGGA_PASSWORD
!
log file $BGPD_LOG
!debug bgp events
!debug bgp zebra
debug bgp updates
!
router bgp 65000
bgp router-id $CUSTOMER_ADDR
network $T1_IN_CUSTOMER_GW
network $T2_IN_CUSTOMER_GW
! Routing for VPC to CUSTOMER (see Route Tables on VPC Console)
! if CustomerVPN forward using NAT, this is unnecessary.
network $CUSTOMER_SUBNET
!
! aws tunnel #1 neighbor
neighbor $T1_NEIGHBOR_ADDR remote-as $T1_ASN
! aws tunnel #2 neighbor
neighbor $T2_NEIGHBOR_ADDR remote-as $T2_ASN
!
line vty
EOT

#
# zebra config
#

cat << EOT > /etc/quagga/zebra.conf
hostname $HOSTNAME
password $QUAGGA_PASSWORD
enable password $QUAGGA_PASSWORD
!
! list interfaces
interface $INTERFACE
interface lo
!
line vty
EOT

#
# Racoon log
#

sed -i "s|RACOON_ARGS.*$|RACOON_ARGS='-l $RACOON_LOG'|g" /etc/default/racoon

cat << EOT > /etc/logrotate.d/racoon
$RACOON_LOG {
	rotate 10
	daily
	compress
	missingok
	notifempty
	copytruncate
}
EOT


#
# Enable zebra and bgpd
#

sed -i 's/zebra=no/zebra=yes/' /etc/quagga/daemons
sed -i 's/bgpd=no/bgpd=yes/'   /etc/quagga/daemons

#
# Create Static Tunnel Addr
#

ip addr add $T1_IN_CUSTOMER_GW dev $INTERFACE
ip addr add $T2_IN_CUSTOMER_GW dev $INTERFACE

#
# Restart Services
#

service racoon restart
service setkey restart
service quagga restart
