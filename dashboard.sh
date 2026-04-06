#!/bin/bash

# nano-node-dashboard.sh
# A real-time monitoring script for your Nano Node

# Colors
MAGENTA='\e[35m'
RED='\e[31m'
YELLOW=$'\033[93m'
BLUE=$'\033[94m'
NC=$'\033[0m'
RESET='\e[0m'

# Yellow "Initializing..." placeholder for fields that need RPC
INIT="${YELLOW}Initializing...${NC}"

is_node_running() {
  docker ps -q -f name=nano-node -f status=running | grep -q .
}

# Check if node RPC is ready by testing telemetry response
is_rpc_ready() {
  local response
  response=$(curl -s --max-time 3 -d '{"action":"telemetry"}' http://localhost:7076 2>/dev/null)
  echo "$response" | grep -q "block_count"
}

# Fetch highest block count from 6 public Nano endpoints (URLs are Base64 encoded)
get_network_block() {
  local encoded="aHR0cHM6Ly9ycGMubmFuby50bwpodHRwczovL3JhaW5zdG9ybS5jaXR5L2FwaQpodHRwczovL25vZGUuc29tZW5hbm8uY29tL3Byb3h5Cmh0dHBzOi8vYXBwLm5hdHJpdW0uaW8vYXBpCmh0dHBzOi8vbmFub3Nsby4xbmEubm8vcHJveHkKaHR0cHM6Ly9ibG9ja2xhdHRpY2UuaW8vYXBpL3JwYw=="
  local highest=0
  while IFS= read -r ep; do
    local count
    count=$(curl -sf --max-time 2 -X POST "$ep" \
      -H "Content-Type: application/json" \
      -d '{"action":"block_count"}' 2>/dev/null \
      | grep -oP '"count":\s*"\K\d+' | head -1)
    if [[ -n "$count" ]] && (( count > highest )); then
      highest=$count
    fi
  done < <(echo "$encoded" | base64 -d | shuf)
  echo "$highest"
}

show_offline_banner() {
  clear
  echo "======================================================================"
  echo "                     NANO NODE DASHBOARD"
  echo "======================================================================"
  echo " Last Updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "----------------------------------------------------------------------"
  echo ""
  echo "                   *** NODE IS STOPPED ***"
  echo ""
  echo "----------------------------------------------------------------------"
  echo -e " [${RED}S${RESET}] Start Node        [${RED}CTRL+C${RESET}] Exit Dashboard"
  echo "======================================================================"
}

show_message() {
  local msg=$1
  clear
  echo "======================================================================"
  echo "                     NANO NODE DASHBOARD"
  echo "======================================================================"
  echo ""
  echo "  >>> $msg"
  echo ""
  echo "======================================================================"
}

run_dashboard() {
  clear

  # --- Gather all data first ---

  # CPU & RAM
  stats=$(docker stats nano-node --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}")
  cpu_perc=$(echo "$stats" | cut -d'|' -f1 | tr -d '%')
  node_ram=$(echo "$stats" | cut -d'|' -f2 | sed 's/GiB/ GB/g; s/MiB/ MB/g' | awk '{print $1, $2}')
  sys_total_ram=$(free -h | awk '/^Mem:/{print $2}' | sed 's/Gi/ GB/g; s/Mi/ MB/g')

  # CPU frequency & cores
  max_ghz=$(awk '/^cpu MHz/{printf "%.2f GHz\n", $4/1000; exit}' /proc/cpuinfo)
  [ -z "$max_ghz" ] && max_ghz="N/A"
  physical_cores=$(lscpu -p | grep -v '^#' | sort -u -t, -k 2,4 | wc -l)
  total_threads=$(nproc)

  # LMDB
  lmdb_mem=$(docker exec nano-node top -bn1 | grep nano_no | head -1 | awk '{print $6}')

  # Power estimate
  power_and_cpu=$(python3 -c "
perc=$cpu_perc; cores=$physical_cores; threads=$total_threads; max_g='$max_ghz'; sys_tot='$sys_total_ram'; lmdb='$lmdb_mem'
norm_perc = perc / threads
core_usage = max(0.5, round(norm_perc/100, 2))
lmdb_num = float(lmdb[:-1]) if lmdb else 0
lmdb_unit = lmdb[-1].lower() if lmdb else 'g'
lmdb_gb = lmdb_num if lmdb_unit == 'g' else lmdb_num / 1024
import re
sys_match = re.match(r'([\d.]+)', sys_tot)
sys_gb = float(sys_match.group(1)) if sys_match else 8.0
cpu_w = (cores * 5) * core_usage
thread_w = (threads * 0.05) * core_usage
ram_w = (lmdb_gb + sys_gb * 0.25) * 1.5
io_w = 5
total_w = cpu_w + thread_w + ram_w + io_w
if max_g not in ('N/A', ''):
    cpu_ghz = f'{norm_perc/100 * float(max_g.split()[0]):.2f} GHz / {max_g}'
else:
    cpu_ghz = 'N/A'
print(f'{cpu_ghz}|{core_usage}|{lmdb_gb:.2f}|{total_w:.0f}')
")
  cpu_ghz=$(echo "$power_and_cpu" | cut -d'|' -f1)
  core_usage=$(echo "$power_and_cpu" | cut -d'|' -f2)
  lmdb_gb=$(echo "$power_and_cpu" | cut -d'|' -f3)
  power_w=$(echo "$power_and_cpu" | cut -d'|' -f4)

  # Internet
  IFACE=$(ip route get 1.1.1.1 | awk '{print $5}')
  read rx1 tx1 < <(awk -v iface="$IFACE" '$1 ~ iface {print $2,$10}' /proc/net/dev)
  sleep 1
  read rx2 tx2 < <(awk -v iface="$IFACE" '$1 ~ iface {print $2,$10}' /proc/net/dev)
  dl=$(echo "scale=2; ($rx2-$rx1)*8/1048576" | bc)
  ul=$(echo "scale=2; ($tx2-$tx1)*8/1048576" | bc)

  # Uptime (does not need RPC)
  m=$(wc -l < /home/nano-data/uptime_minutes.txt)
  cumulative="$((m/1440))d $((m%1440/60))h $((m%60))m"
  created_ts=$(docker inspect nano-node -f '{{.Created}}')
  created_secs=$(date -d "$created_ts" +%s)
  now_secs=$(date +%s)
  elapsed=$(( now_secs - created_secs ))
  created_d=$((elapsed/86400)); created_h=$(( (elapsed%86400)/3600 )); created_m=$(( (elapsed%3600)/60 ))
  created_since="${created_d}d ${created_h}h ${created_m}m"
  concurrent=$(docker ps --filter "name=nano-node" --format "{{.Status}}" | sed 's/Up //')
  total_mins=$(( elapsed / 60 ))
  active_pct=$(python3 -c "print(f'{($m / $total_mins * 100):.2f}%')")

  # Network block count (external endpoints, always available)
  net_block=$(get_network_block)

  # RPC-dependent fields — check if node is ready first
  if is_rpc_ready; then
    tel=$(curl -s -d '{"action":"telemetry"}' http://localhost:7076)
    node_block=$(echo "$tel" | grep -oP '"block_count":\s*"\K\d+')
    peer_count=$(echo "$tel" | grep -oP '"peer_count":\s*"\K\d+')
    v_maj=$(echo "$tel" | grep -oP '"major_version":\s*"\K\d+')
    v_min=$(echo "$tel" | grep -oP '"minor_version":\s*"\K\d+')
    v_pat=$(echo "$tel" | grep -oP '"patch_version":\s*"\K\d+')
    b_cap=$(echo "$tel" | grep -oP '"bandwidth_cap":\s*"\K\d+')
    node_id=$(echo "$tel" | grep -oP '"node_id":\s*"\K[^"]+')
    bw_cap="$((b_cap/1048576)) MB/s"
    node_version="V$v_maj.$v_min.$v_pat"

    # Sync calculation
    sync_line=$(python3 -c "
nb=$node_block if '$node_block' else 0
net=$net_block if '$net_block' else 0
if net == 0:
    print('N/A|N/A')
elif nb >= net:
    print('0|100%')
else:
    gap = net - nb
    pct = nb / net * 100
    pct_truncated = int(pct * 1000) / 1000
    print(f'{gap}|{pct_truncated:.3f}%')
")
    blocks_gap=$(echo "$sync_line" | cut -d'|' -f1)
    sync_pct=$(echo "$sync_line" | cut -d'|' -f2)

    # Display values
    blocks_gap_display="$blocks_gap"
    sync_pct_display="$sync_pct"
    peer_count_display="$peer_count"
    bw_cap_display="$bw_cap"
    node_version_display="$node_version"
    node_id_display="$node_id"
  else
    # Node is running but RPC not ready yet — show Initializing for affected fields
    node_block=""
    blocks_gap_display="$INIT"
    sync_pct_display="$INIT"
    peer_count_display="$INIT"
    bw_cap_display="$INIT"
    node_version_display="$INIT"
    node_id_display="$INIT"
  fi

  # --- Render dashboard ---
  echo "======================================================================"
  echo "                     NANO NODE DASHBOARD"
  echo "======================================================================"
  echo " Last Updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "----------------------------------------------------------------------"
  echo " Node's System Usage"
  echo "----------------------------------------------------------------------"
  printf " %-22s %s\n" "CPU Usage"          "$cpu_ghz"
  printf " %-22s %s\n" "CPU Core Usage"     "$core_usage core / $physical_cores cores"
  printf " %-22s %s\n" "Node RAM Usage"     "$node_ram / $sys_total_ram"
  printf " %-22s %-12s %s\n" "LMDB Memory Map"    "${lmdb_gb} GB"  "(Ledger mapped into RAM by LMDB)"
  printf " %-22s %-12s %s\n" "Power Est. (Watts)" "${power_w} Watts" "(Incl. LMDB Overhead and I/O)"
  printf " %-22s %s\n" "Internet Usage"     "${dl} Mbps Down / ${ul} Mbps Up"
  printf " %-22s %b\n" "Bandwidth Cap"      "$bw_cap_display"
  echo "----------------------------------------------------------------------"
  echo " Node Uptime Status"
  echo "----------------------------------------------------------------------"
  printf " %-22s %s\n" "Service Status"     "Running"
  printf " %-22s %s\n" "Created Since"      "$created_since"
  printf " %-22s %s\n" "Concurrent Uptime"  "$concurrent"
  printf " %-22s %s\n" "Cumulative Uptime"  "$cumulative"
  printf " %-22s %s\n" "Active Uptime %"    "$active_pct"
  echo "----------------------------------------------------------------------"
  echo " Node Sync Status"
  echo "----------------------------------------------------------------------"
  if [[ -n "$node_block" ]]; then
    printf " %-22s ${BLUE}%-12s${NC} %s\n" "Block Count"    "$node_block" "(Your Node's Block)"
  else
    printf " %-22s %b\n" "Block Count"    "$INIT"
  fi
  printf " %-22s %-12s %s\n" "Nano Block"     "$net_block" "(Latest Nano Network's Block)"
  printf " %-22s %b\n" "Blocks Gap"         "$blocks_gap_display"
  printf " %-22s %b\n" "Sync %"             "$sync_pct_display"
  printf " %-22s %b\n" "Peer Count"         "$peer_count_display"
  echo "----------------------------------------------------------------------"
  echo " Node Info"
  echo "----------------------------------------------------------------------"
  printf " %-22s %b\n" "Node Version"       "$node_version_display"
  printf " %-22s %b\n" "Node ID"            "$node_id_display"
  echo "----------------------------------------------------------------------"
  echo -e " [${RED}X${RESET}] Stop Node   [${RED}S${RESET}] Start Node   [${RED}R${RESET}] Restart Node   [${RED}CTRL+C${RESET}] Exit"
  echo " Auto-refreshing every 30 seconds. Press [CTRL+C] to stop"
  echo " Your Nano node will keep running even if you stop dashboard"
  echo -e " To check dashboard again (if stopped) just type ${MAGENTA}dashboard${RESET}"
  echo "======================================================================"
}

handle_keys() {
  local end=$((SECONDS + 30))
  while [ $SECONDS -lt $end ]; do
    if read -r -s -n1 -t1 key; then
      case "$key" in
        X|x)
          if is_node_running; then
            show_message "Stopping Nano Node..."
            sudo docker stop nano-node
            sleep 2
          fi
          return
          ;;
        S|s)
          if ! is_node_running; then
            show_message "Starting Nano Node... please wait"
            sudo docker start nano-node
            sleep 10
          fi
          return
          ;;
        R|r)
          show_message "Restarting Nano Node... please wait"
          sudo docker restart nano-node
          sleep 10
          return
          ;;
      esac
    fi
  done
}

# Main loop
while true; do
  if is_node_running; then
    run_dashboard
  else
    show_offline_banner
  fi
  handle_keys
done
