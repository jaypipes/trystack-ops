# Installs and sets up the Chef Server

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
