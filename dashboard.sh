#!/bin/bash

# nano-node-dashboard.sh
# A real-time monitoring script for your Nano Node

# Colors
MAGENTA='\e[35m'
RED='\e[31m'
BLUE=$'\033[94m'
NC=$'\033[0m'
RESET='\e[0m'

is_node_running() {
  docker ps -q -f name=nano-node -f status=running | grep -q .
}

show_offline_banner() {
  clear
  echo "==============================================================="
  echo "                NANO NODE MINI-DASHBOARD"
  echo "==============================================================="
  echo " Last Updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "---------------------------------------------------------------"
  echo ""
  echo "              *** NODE IS STOPPED ***"
  echo ""
  echo "---------------------------------------------------------------"
  echo -e " [${RED}S${RESET}] Start Node        [${RED}CTRL+C${RESET}] Exit Dashboard"
  echo "==============================================================="
}

show_message() {
  local msg=$1
  clear
  echo "==============================================================="
  echo "                NANO NODE MINI-DASHBOARD"
  echo "==============================================================="
  echo ""
  echo "  >>> $msg"
  echo ""
  echo "==============================================================="
}

run_dashboard() {
  clear
  echo "==============================================================="
  echo "                NANO NODE MINI-DASHBOARD"
  echo "==============================================================="
  echo " Last Updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "---------------------------------------------------------------"

  {
    echo "PARAMETER|VALUE"
    docker ps --filter "name=nano-node" --format "Name|Nano Node\nCreated Since|{{.RunningFor}}\nConcurrent Uptime|{{.Status}}" | sed 's/Up //'
    m=$(wc -l < /home/nano-data/uptime_minutes.txt); echo "Cumulative Uptime|$((m/1440))d $((m%1440/60))h $((m%60))m"
    total_mins=$(( ($(date +%s) - $(date -d "$(docker inspect nano-node -f '{{.Created}}')" +%s)) / 60 ))
    python3 -c "print(f'Active Uptime %|{($m / $total_mins * 100):.2f}%')"
    stats=$(docker stats nano-node --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}")
    cpu_perc=$(echo $stats | cut -d'|' -f1 | tr -d '%'); mem_usage=$(echo $stats | cut -d'|' -f2 | sed 's/GiB/ GB/g; s/MiB/ MB/g')
    max_ghz=$(awk '/^cpu MHz/{printf "%.2f GHz\n", $4/1000; exit}' /proc/cpuinfo)
    [ -z "$max_ghz" ] && max_ghz="N/A"
    physical_cores=$(lscpu -p | grep -v '^#' | sort -u -t, -k 2,4 | wc -l)
    total_threads=$(nproc)
    sys_total=$(free -g | awk '/^Mem:/{print $2}')
    python3 -c "perc=$cpu_perc; cores=$physical_cores; threads=$total_threads; max_g='$max_ghz'; ram_str='$mem_usage'; sys_tot=$sys_total;
norm_perc = perc / threads
parts=ram_str.split(); val=float(parts[0]); unit=parts[1];
ram_gb = val if unit=='GB' else val/1024
total_impact = ram_gb + (sys_tot * 0.25)
cpu_w=(cores*5)*(norm_perc/100); ram_w=total_impact*1.5;
if max_g not in ('N/A', ''):
    cpu_ghz_str = f'{norm_perc/100 * float(max_g.split()[0]):.2f} GHz / {max_g}'
else:
    cpu_ghz_str = 'N/A'
print(f'CPU Usage|{cpu_ghz_str}\nCPU Core Usage|{max(0.01, round(norm_perc/100, 2))} core / {cores} cores\nRAM Usage|{ram_str}\nPower Consumption (Est.)|{(cpu_w + ram_w):.2f} Watts (Incl. Ledger Cache Overhead)')"
    IFACE=$(ip route get 1.1.1.1 | awk '{print $5}'); read rx1 tx1 < <(awk -v iface="$IFACE" '$1 ~ iface {print $2,$10}' /proc/net/dev); sleep 1; read rx2 tx2 < <(awk -v iface="$IFACE" '$1 ~ iface {print $2,$10}' /proc/net/dev)
    echo "Internet Usage|$(echo "scale=1; ($rx2-$rx1)*8/1048576" | bc) Mbps Down / $(echo "scale=1; ($tx2-$tx1)*8/1048576" | bc) Mbps Up"
    tel=$(curl -s -d '{"action":"telemetry"}' http://localhost:7076)
    echo "Block Count|$(echo "$tel" | grep -oP '\"block_count\":\s*\"\K\d+')"
    echo "Peer Count|$(echo "$tel" | grep -oP '\"peer_count\":\s*\"\K\d+')"
    v_maj=$(echo "$tel" | grep -oP '\"major_version\":\s*\"\K\d+'); v_min=$(echo "$tel" | grep -oP '\"minor_version\":\s*\"\K\d+'); v_pat=$(echo "$tel" | grep -oP '\"patch_version\":\s*\"\K\d+')
    echo "Node Version|$v_maj.$v_min.$v_pat"
    b_cap=$(echo "$tel" | grep -oP '\"bandwidth_cap\":\s*\"\K\d+'); echo "Bandwidth Cap|$((b_cap/1048576)) MB/s"
    echo "Node ID|$(echo "$tel" | grep -oP '\"node_id\":\s*\"\K[^"]+')"
  } | column -t -s "|" | sed "s/\(Block Count[ ]*\)\([0-9]\+\)/\1${BLUE}\2${NC}/"

  echo "---------------------------------------------------------------"
  echo -e " [${RED}X${RESET}] Stop Node   [${RED}S${RESET}] Start Node   [${RED}R${RESET}] Restart Node   [${RED}CTRL+C${RESET}] Exit"
  echo " Auto-refreshing every 30 seconds. Press [CTRL+C] to stop"
  echo " Your Nano node will keep running even if you stop dashboard"
  echo -e " To check dashboard again (if stopped) just type ${MAGENTA}dashboard.sh${RESET}"
  echo "==============================================================="
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
