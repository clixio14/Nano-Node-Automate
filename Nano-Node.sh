#!/bin/bash
# Exit on any error
set -e

# 1. Update and upgrade
sudo apt update -y

# 2. Basic tools
sudo apt install -y build-essential curl git

echo "# Installing 7 zip to extract Nano Node ledger snapshot later"
# 3. 7zip
sudo apt update && sudo apt install -y p7zip-full

echo "# Downloading script to install Nano Dashboard"
# 4. Dashboard Script
sudo curl -sSL https://raw.githubusercontent.com/clixio14/Nano-Node-Automate/refs/heads/main/dashboard.sh -o /usr/local/bin/dashboard.sh && sudo chmod +x /usr/local/bin/dashboard.sh

echo "# Creating folders"
# 5. Folders
sudo mkdir -p /home/nano-data/Nano/
# Ensure permissions for the odometer file
sudo chown -R $USER:$USER /home/nano-data/

echo "# Adding a cron job + odometer to be able to check the node's Cumulative Uptime whenever you want"
echo "# Cumulative Uptime = The actual uptime of the node ever since first run, minus, the node restarts or stops or server resets/shutdowns"
# 6. Odometer Setup
(crontab -l 2>/dev/null; echo "* * * * * pgrep nano_node && echo \"1\" >> /home/nano-data/uptime_minutes.txt") | crontab -
echo "# Odometer is now active and will record every minute the node is running"

echo "# let's download the latest snapshot of the ledger even before running the Nano Node."
echo "# This is so that we can save nearly 90+ hours of boostrapping/syncing which requires unneccessarily high RAM/Disk IO usage." 
echo "# Downloading the zip file of the latest snapshot of the Nano Node ledger"
# 7. Ledger Download (using -nc to skip if exists)
wget -nc $(curl -s https://s3.us-east-2.amazonaws.com/repo.nano.org/snapshots/latest) -O /home/nano-data/Nano/Nano_Snapshot.7z
echo "# Download Complete"

echo "# Exctracting the Zip File"
# 8. Extraction
7z x /home/nano-data/Nano/Nano_Snapshot.7z -o/home/nano-data/Nano/ -y
echo "# Ledger snapshot has been downloaded and Extracted into nano-data/Nano"

echo "# Next, let's create (prefilled) standard Config Files if we need to change it later."
echo "# Creating config-node.toml"
# 9. Node Config
curl -sL https://pastebin.com/raw/8ibFAd3F -o /home/nano-data/Nano/config-node.toml
echo "# Creating config-rpc.toml"
# 10. RPC Config
curl -sL https://pastebin.com/raw/pTyMw7mF -o /home/nano-data/Nano/config-rpc.toml

echo "# Next let's install docker and run the latest version of Nano Node in it"
# 11. Update for Docker
sudo apt update
echo "# Installing Docker"
# 12. Docker install
sudo apt install -y docker.io
echo "# Starting Docker"
# 13. Service start
sudo service docker start
# 14. Group setup
sudo usermod -aG docker $USER

echo "# Now let's download the latest version of the Nano Node and start it"
# 15. Docker Run ((First run of Fast Sync'd Nano Node)
sudo docker run --restart=unless-stopped -d \
  -p 7075:7075 \
  -p 127.0.0.1:7076:7076 \
  -p 127.0.0.1:7078:7078 \
  -v /home/nano-data:/root \
  --name nano-node nanocurrency/nano:V28.2

echo "# That's it, your Nano Node will start running with almost 98% sync because we already downloaded the latest snapshot of the ledger"
echo "# You have saved nearly 90+ hours of bootstrapping time and 4TB of Write IO data by using Fast Sync technique"

echo "# ------------------------------------------------------------"
echo " "
echo -e "# To See a live Dashboard for your node just type: \e[35mdashboard.sh\e[0m"
echo " "
echo "# ------------------------------------------------------------"

# 16. Refresh group
newgrp docker
