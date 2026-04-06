#!/bin/bash
# Exit on any error
set -e

# 1. Update and upgrade
sudo apt update -y

# 2. Basic tools
sudo apt install -y build-essential curl git

echo "# Installing 7zip to extract Nano Node ledger snapshot later"
# 3. 7zip
sudo apt install -y p7zip-full

echo "# Downloading latest dashboard script"
# 4. Dashboard Script — always re-downloaded to pick up any updates
sudo curl -sSL https://raw.githubusercontent.com/clixio14/Nano-Node-Automate/refs/heads/main/dashboard.sh -o /usr/local/bin/dashboard.sh && sudo chmod +x /usr/local/bin/dashboard.sh

echo "# Creating folders"
# 5. Folders — mkdir -p and chown are safe to re-run
sudo mkdir -p /home/nano-data/Nano/
sudo chown -R $USER:$USER /home/nano-data/

# 6. aria2 — skip if already installed
if ! command -v aria2c &>/dev/null; then
  echo "# Installing aria2 download manager"
  sudo apt install -y aria2
else
  echo "# aria2 already installed, skipping"
fi

# 7. Ledger Download — skip if already downloaded
if [ -f /home/nano-data/Nano/Nano_Snapshot.7z ]; then
  echo "# Ledger snapshot already downloaded, skipping"
else
  echo "# Downloading the latest snapshot of the Nano Node ledger"
  echo "# This saves 90+ hours of bootstrapping and 4TB of Write IO"
  aria2c -x 16 -s 16 -o Nano_Snapshot.7z -d /home/nano-data/Nano/ $(curl -s https://s3.us-east-2.amazonaws.com/repo.nano.org/snapshots/latest)
  echo "# Download Complete"
fi

# 8. Extraction — skip if ledger already extracted
if [ -f /home/nano-data/Nano/data.ldb ]; then
  echo "# Ledger already extracted, skipping"
else
  echo "# Extracting the ledger snapshot"
  7z x /home/nano-data/Nano/Nano_Snapshot.7z -o/home/nano-data/Nano/ -y
  echo "# Ledger extracted into /home/nano-data/Nano"
fi

# 9. Node Config — always re-downloaded to pick up any updates
echo "# Downloading config-node.toml"
curl -sL https://raw.githubusercontent.com/clixio14/Nano-Node-Automate/refs/heads/main/config-node.toml -o /home/nano-data/Nano/config-node.toml

# 10. RPC Config — always re-downloaded to pick up any updates
echo "# Downloading config-rpc.toml"
curl -sL https://raw.githubusercontent.com/clixio14/Nano-Node-Automate/refs/heads/main/config-rpc.toml -o /home/nano-data/Nano/config-rpc.toml

# 11. Docker install — skip if already installed
if ! command -v docker &>/dev/null; then
  echo "# Installing Docker"
  sudo apt update
  sudo apt install -y docker.io
  echo "# Starting Docker"
  sudo service docker start
  sudo usermod -aG docker $USER
else
  echo "# Docker already installed, skipping"
  # Start docker if stopped — || true prevents set -e from killing script if already running
  sudo service docker start || true
fi

# 12. Nano Node — version auto-detection and re-run protection
echo "# Checking latest Nano Node version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/nanocurrency/nano-node/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+')
echo "# Latest Nano Node version available: $LATEST_VERSION"

# Track whether the node was actually started/updated (used for sleep decision below)
NODE_JUST_STARTED=false

CONTAINER_EXISTS=$(sudo docker ps -a -q -f name=nano-node)

if [ -n "$CONTAINER_EXISTS" ]; then
  # Container exists — check its current version
  CURRENT_VERSION=$(sudo docker inspect nano-node --format '{{.Config.Image}}' | grep -oP 'V[\d.]+')
  echo "# Currently installed Nano Node version: $CURRENT_VERSION"

  if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    # Same version — just make sure it's running
    CONTAINER_RUNNING=$(sudo docker ps -q -f name=nano-node -f status=running)
    if [ -n "$CONTAINER_RUNNING" ]; then
      echo "# Nano Node is already running on the latest version ($CURRENT_VERSION), skipping"
    else
      echo "# Nano Node container exists but is stopped — starting it"
      sudo docker start nano-node
      NODE_JUST_STARTED=true
    fi
  else
    # Newer version available — update
    echo "# Newer version available ($LATEST_VERSION) — updating Nano Node..."
    sudo docker stop nano-node || true
    sudo docker rm nano-node
    sudo docker pull nanocurrency/nano:$LATEST_VERSION
    sudo docker run --restart=unless-stopped -d \
      -p 7075:7075 \
      -p 127.0.0.1:7076:7076 \
      -p 127.0.0.1:7078:7078 \
      -v /home/nano-data:/root \
      --name nano-node nanocurrency/nano:$LATEST_VERSION
    echo "# Nano Node updated to $LATEST_VERSION"
    NODE_JUST_STARTED=true
  fi
else
  # Fresh install — run the container
  echo "# No existing container found — installing Nano Node $LATEST_VERSION"
  sudo docker run --restart=unless-stopped -d \
    -p 7075:7075 \
    -p 127.0.0.1:7076:7076 \
    -p 127.0.0.1:7078:7078 \
    -v /home/nano-data:/root \
    --name nano-node nanocurrency/nano:$LATEST_VERSION
  NODE_JUST_STARTED=true
fi

# Only wait if the node was just started or updated — skip on re-runs where nothing changed
if [ "$NODE_JUST_STARTED" = true ]; then
  echo "# Node initializing, please wait..."
  sleep 45
fi

echo "# Adding a cron job + odometer to be able to check the node's Cumulative Uptime whenever you want"

# 13. Odometer Setup — touch and chmod are safe to re-run
sudo chmod 777 /home/nano-data/
sudo touch /home/nano-data/uptime_minutes.txt
sudo chmod 777 /home/nano-data/uptime_minutes.txt

# Crontab — skip if entry already exists
if sudo crontab -l 2>/dev/null | grep -q "uptime_minutes.txt"; then
  echo "# Cron job already exists, skipping"
else
  (sudo crontab -l 2>/dev/null || true; echo "* * * * * /usr/bin/docker ps -q -f name=nano-node -f status=running | grep -q . && echo \"1\" >> /home/nano-data/uptime_minutes.txt") | sudo crontab -
  echo "# Odometer is now active and will record every minute the node is running"
fi

if [ "$NODE_JUST_STARTED" = true ]; then
  sleep 15
fi

echo "# Node setup complete"
echo "# Your Nano Node is running with almost 98% sync because we already downloaded the latest snapshot of the ledger"
echo "# You have saved nearly 90+ hours of bootstrapping time and 4TB of Write IO data by using Fast Sync technique"

echo "# ------------------------------------------------------------"
echo " "
echo -e "# To See a live Dashboard open a new terminal & just type: \e[35mdashboard\e[0m"
echo " "
echo "# ------------------------------------------------------------"

# 14. Wrapper script — lets user type 'dashboard' instead of 'dashboard.sh'
# Ensures permissions are always correct before launching dashboard
# Remove any existing symlink first to prevent printf following it and overwriting dashboard.sh
sudo rm -f /usr/local/bin/dashboard
printf '#!/bin/bash\nsudo chmod +x /usr/local/bin/dashboard.sh\nexec /usr/local/bin/dashboard.sh\n' | sudo tee /usr/local/bin/dashboard > /dev/null
sudo chmod +x /usr/local/bin/dashboard

# 15. Refresh group
newgrp docker
