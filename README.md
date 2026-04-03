# Quick-Nano-Node-Setup

User friendly (Even Users with just very basic Linux knowledge can run a Nano Node on Linux)
Beginner friendly + complete automation

Get a new Linux Server with Ubuntu OS (VPS or Dedicated Server).
Login to your terminal via SSH.

Paste this single line (including curl and bash) into the terminal and hit ENTER button:

curl -sL https://raw.githubusercontent.com/clixio14/Nano-Node-Automate/refs/heads/main/Nano-Node.sh | bash  

  
The above single command executes the entire script.  
It runs the latest version of Nano Node + Fast Sync.  
It will also save you nearly 90+ hours of bootstrapping time and avoids 4TB or Disk IO usage.  
The script also installs a mini dashboard script for your Nano Node


# What this script automatically does:
1. Update and upgrade Linux packages
2. Installs Basic tools
3. Installs 7zip (to extract ledger snapshot)
4. Creates Dashboard script (A tiny custom script)
5. Creates Folders
6. Odometer Setup (If user wants to check Cumulative Uptime of the Node)
7. Downloads latest Ledger Snapshot (using -nc to skip if exists)
8. Extracts the downloaded 7zip file (Hence step 3 was required)
9. Create config-node.toml
10. Create config-rpc.toml
11. Update for Docker
12. Docker install
13. Service start
14. Group setup
15. Docker Run (First run of Fast Sync'd Nano Node)
16. Refresh group (Script End. Dsiplays a useful Dashboard command)

# Live Dashboard
After complete auto installation and running of the node, to see a live mini dashboard of the node just type:

dashboard.sh

----------------------------------------------------------------------------------------------------------------

# Note 1 (System Specs for Nano Node)
To run a normal Nano Node, below is the minimum System Specs required for your Linux server, :
1. CPU: 2 Cores
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
