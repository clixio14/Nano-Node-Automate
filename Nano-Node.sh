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

sudo apt install -y aria2

echo "# let's download the latest snapshot of the ledger even before running the Nano Node."
echo "# This is so that we can save nearly 90+ hours of boostrapping/syncing which requires unneccessarily high RAM/Disk IO usage." 
echo "# Downloading the zip file of the latest snapshot of the Nano Node ledger"
# 6. Ledger Download (using -nc to skip if exists)
aria2c -x 16 -s 16 -o Nano_Snapshot.7z -d /home/nano-data/Nano/ $(curl -s https://s3.us-east-2.amazonaws.com/repo.nano.org/snapshots/latest)
echo "# Download Complete"

echo "# Exctracting the Zip File"
# 7. Extraction
7z x /home/nano-data/Nano/Nano_Snapshot.7z -o/home/nano-data/Nano/ -y
echo "# Ledger snapshot has been downloaded and Extracted into nano-data/Nano"

echo "# Next, let's create (prefilled) standard Config Files if we need to change it later."
echo "# Creating config-node.toml"
# 8. Node Config
curl -sL https://pastebin.com/raw/8ibFAd3F -o /home/nano-data/Nano/config-node.toml
echo "# Creating config-rpc.toml"
# 9. RPC Config
curl -sL https://pastebin.com/raw/pTyMw7mF -o /home/nano-data/Nano/config-rpc.toml

echo "# Next let's install docker and run the latest version of Nano Node in it"
# 10. Update for Docker
sudo apt update
echo "# Installing Docker"
# 11. Docker install
sudo apt install -y docker.io
echo "# Starting Docker"
# 12. Service start
sudo service docker start
# 13. Group setup
sudo usermod -aG docker $USER

echo "# Now let's download the latest version of the Nano Node and start it"
# 14. Docker Run ((First run of Fast Sync'd Nano Node)
sudo docker run --restart=unless-stopped -d \
  -p 7075:7075 \
  -p 127.0.0.1:7076:7076 \
  -p 127.0.0.1:7078:7078 \
  -v /home/nano-data:/root \
  --name nano-node nanocurrency/nano:V28.2

# Wait 45 seconds to ensure the node has actually initialized
sleep 45
echo "# Adding a cron job + odometer to be able to check the node's Cumulative Uptime whenever you want"
# 15. Odometer Setup
sudo chmod 777 /home/nano-data/
# Create Cronjob file
sudo touch /home/nano-data/uptime_minutes.txt
sudo chmod 777 /home/nano-data/uptime_minutes.txt
# Run Cronjob
(crontab -l 2>/dev/null; echo "* * * * * pgrep nano_node && echo \"1\" >> /home/nano-data/uptime_minutes.txt") | crontab -
echo "# Odometer is now active and will record every minute the node is running"
sleep 15
echo "# Node setup complete"
echo "# Your Nano Node is running with almost 98% sync because we already downloaded the latest snapshot of the ledger"
echo "# You have saved nearly 90+ hours of bootstrapping time and 4TB of Write IO data by using Fast Sync technique"

echo "# ------------------------------------------------------------"
echo " "
echo -e "# To See a live Dashboard open a new terminal & just type: \e[35mdashboard.sh\e[0m"
echo " "
echo "# ------------------------------------------------------------"

# 16. Refresh group
newgrp docker
