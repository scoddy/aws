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
apt-get install racoon ipsec-tools quagga dnsutils tcpdump vim mtr-tiny git 

```
* Racoon Config: direct
* edit /etc/hostname: ins-natvpn-eu-central-1a
* edit /etc/hosts - append hostname to 127.0.0.1

* Reboot

#### IPSec Config

* Complete AWS Configuration
* Download Vendor Agnostic VPN Configuration


