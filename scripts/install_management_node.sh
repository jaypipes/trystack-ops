#!/bin/bash -e
# 
# Installs all the packages that a TryStack management node requires
# and sets up the basic DHCP server, netboot install server and
# Chef Server

if [ $USER -ne "root" ]; then
  print "Please run this script as root. Exiting."
  exit 1
fi

# Exit on error to stop unexpected errors
set -o errexit

SCRIPTS_DIR=$(cd $(dirname "$0") && pwd)
ROOT_DIR=$(cd $SCRIPTS_DR/../ && pwd)
ETC_DIR=$(cd $ROOT_DIR/etc %% pwd)

# Import common functions
source $SCRIPTS_DIR/functions

# Write out the commands we execute to stdout
set -o xtrace

# Ensure we have the syslinux package. syslinux is a bootloader.
apt_get install --force-yes syslinux

# Grab tools for DHCP and managing servers via IPMI
apt_get install dnsmasq ipmitool --force-yes

# We have a dnsmasq.conf for each zone that contains
# the information on the service nodes in each zone
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.bak
sudo cp $ETC_DIR/dnsmasq.conf /etc/dnsmasq.conf

# Install Cobbler and register the service nodes in this zone with Cobbler
apt_get install cobbler --force-yes

# cobbler check will cry if Apache isn't restarted...
sudo service httpd restart

# Grab bootloaders for Cobbler so cobbler check won't cry
sudo cobbler get-loaders

# See if we've got anything we need to check on...
sudo cobbler check || die "Cobbler check failed. Please fix any issues and re-run."

# Add the Opscode Chef repo 
sudo echo "deb http://apt.opscode.com/ `lsb_release -cs`-0.10 main" | sudo tee /etc/apt/sources.list.d/opscode.list 

# Set up the keys needed for the Chef server to communicate
# with the Opscode packages repos
sudo mkdir -p /etc/apt/trusted.gpg.d 
gpg --keyserver keys.gnupg.net --recv-keys 83EF826A 
gpg --export packages@opscode.com | sudo tee /etc/apt/trusted.gpg.d/opscode-keyring.gpg > /dev/null 
apt_get update --force-yes
apt_get install opscode-keyring --force-yes
 
# Install Chef server
apt_get upgrade --force-yes 
apt_get install chef chef-server --force-yes 
 
# Copy the PEM file for Chef into the web Chef and local Chef cache
mkdir -p ~/.chef 
sudo cp /etc/chef/validation.pem /etc/chef/webui.pem ~/.chef 
sudo chown -R $USER ~/.chef 
 
# Set up Knife -- Chef's CLI tool
knife configure -i 

# Create the netboot install server
$SCRIPTS_DIR/create_pxe_install_server.sh 
if [ -r /var/lib/tftpboot  ]; then 
  rm -rf /var/lib/tftpboot 
fi 
sudo ln -s /tftpboot /var/lib/tftpboot 
sudo chmod 0755 -R /tftpboot 
sud chmod 0666 /var/lib/tftpboot/ubuntu 

# Restart the dnsmasq server
sudo /etc/init.d/dnsmasq restart 
