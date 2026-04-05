# Quick-Nano-Node-Setup

User friendly (Even Users with just very basic Linux knowledge can run a Nano Node on Linux)
Beginner friendly + complete automation

Get a new Linux Server with Ubuntu OS (VDS or Dedicated Server).
Login to your terminal via SSH.

Paste this single line into the terminal and hit ENTER button:

    curl -sL https://raw.githubusercontent.com/clixio14/Nano-Node-Automate/refs/heads/main/Nano-Node.sh | bash

  
The above single command executes the entire script.  
It runs the latest version of Nano Node + Fast Sync.  
It will also save you nearly 90+ hours of sync time and avoids 4TB or Disk IO usage during bootstrapping.   
This also installs a live dashboard tool for your Nano Node that you can run with a simple command.

Depending on your system specs, your Full sync'd Nano Node will be up and running in under 20 minutes.


# What this script automatically does:
1. Updates Linux packages
2. Installs Basic tools
3. Downloads a Dashboard tool
4. Odometer Setup (To check Cumulative Uptime of the Node)
5. Downloads and extracts latest Ledger Snapshot (using Aria tool for fast download)
6. Installs and starts docker
7. Installs and runs Nano Node on a container
8. Informs users that the Nano Node has started
9. Informs user a short command to run the dashboard tool if they want to see node status

# Live Dashboard
After complete auto installation and running of the node, to see a live dashboard of the node, just type:

    dashboard.sh

----------------------------------------------------------------------------------------------------------------

# Note 1 (System Specs for Nano Node)
To run a normal Nano Node, below is the minimum System Specs required for your Linux server, :
1. CPU: 4 Cores
2. RAM: 6 GB
3. Storage: 200 GB available disk space
4. Internet Speed: 80 Mbps up/down (10 MB/s)

# Note 2 (System Specs for Representative Nano Node)
To run a Representative Node, below is the "minimum" System Specs for your Linux server, :
1. CPU: 4 Cores
2. RAM: 16 GB
3. Disk: SSD (NVME Preferred)
4. Storage: 400 GB available disk space
5. Internet Speed: 400 Mbps up/down (50 MB/s)
