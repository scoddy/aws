## Installation of AWS Debian NAT VPN Instance

### Launch new Instance (Adapt Parameters as necessary)
* Install Instance debian-wheezy-amd64-hvm-2014-10-18-ebs - ami-482a1c55 (m3.medium)
* Select correct VPC / Network (no public IP)
* 8 GB General Purpose SSD
* Tags= Name:ins-natvpn-eu-central-1a Environment:live
* Security Groups: sec-nat-vpc-europe-central-1
* Attach Elastic IP
* Create DNS Record in .awsext.X.net Zone for Public Elastic IP
* Create DNS Record in .awsint.X.net Zone for Private IP

### Configuration of the Instance

#### Base Config

```

apt-get update && apt-get upgrade
apt-get install racoon ipsec-tools quagga dnsutils tcpdump vim mtr-tiny git rcconf tmux screen curl

```
* Racoon Config: direct
* edit /etc/hostname: ins-natvpn-eu-central-1a
* edit /etc/hosts - append hostname to 127.0.0.1

* Reboot

#### IPSec Config

* Complete AWS Configuration
* Download Generic - Vendor Agnostic VPN Configuration

* Download Scripts

``` 
wget https://raw.githubusercontent.com/scoddy/aws/master/aws_vpn_between_vpcgw_and_debian_with_nat.sh
sudo wget -O /etc/init.d/aws-routemon https://raw.githubusercontent.com/scoddy/aws/master/aws-routemon
sudo wget -O /usr/local/bin/aws_routemon.sh https://raw.githubusercontent.com/scoddy/aws/master/aws_routemon.sh
sudo chmod +x /usr/local/bin/aws_routemon.sh /etc/init.d/aws-routemon
chmod +x aws_vpn_between_vpcgw_and_debian_with_nat.sh

```

##### Create initial VPN Config (only for first config, not for additional tunnels)

```
sudo ./aws_vpn_between_vpcgw_and_debian_with_nat.sh vpn-2f5ebd46.txt
sysctl -p --system (copy in sysctl.conf and erase sysctl.d/vpn.conf)

```
* Add required Ipsec Interface Addresses in /etc/network/interfaces

```
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
up ip address add 169.254.255.46/30 dev eth0
up ip address add 169.254.255.42/30 dev eth0
down ip address del 169.254.255.46/30 dev eth0
down ip address del 169.254.255.42/30 dev eth0
```

* modify routemon scripts SA's
