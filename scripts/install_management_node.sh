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
IMAGES_DIR=~/images
PRECISE_DOWNLOAD_URI="http://www.ubuntu.com/start-download?distro=server&bits=64&release=precise"

# Import common functions
source $SCRIPTS_DIR/functions

# Write out the commands we execute to stdout
set -o xtrace

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

# TODO(jaypipes): Copy the $ETC_DIR/cobbler/settings.tpl and
# replace the placeholder variables, then copy into /etc/cobbler.
# Right now, installing Cobbler installs an /etc/cobbler/settings file
# that already has the server and next-server variables set to the
# management node's IP address automatically.

# Grab the base operating system image that will be used
# on the service nodes
mkdir -p $IMAGES_DIR/precise
ISO_FILEPATH=$IMAGES_DIR/precise/ubuntu-12.04-server-i386.iso
if [[ ! -f $ISO_FILEPATH ]]; then
  wget -O $ISO_FILEPATH $PRECISE_DOWNLOAD_URI
fi

# Mount the Precise ISO and import it into Cobbler
PRECISE_MNT_PATH=$IMAGES_DIR/precise/mnt
mkdir -p $PRECISE_MNT_PATH
sudo mount -o loop $ISO_FILEPATH $PRECISE_MNT_PATH
sudo cobbler import --path=$PRECISE_MNT_PATH --name=UbuntuPrecise
sudo cobbler sync

# Install and configure the Chef server
$SCRIPTS_DIR/install_chef_server.sh

# Restart the dnsmasq server
sudo /etc/init.d/dnsmasq restart

# Behave.
exit 0
