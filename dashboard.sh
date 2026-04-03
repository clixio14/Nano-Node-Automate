#!/bin/bash

# nano-node-dashboard.sh
# A real-time monitoring script for your Nano Node

run_dashboard() {
  clear
  echo "==============================================================="
  echo "                NANO NODE MINI-DASHBOARD"
  echo "==============================================================="
  echo " Last Updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "---------------------------------------------------------------"

  { 
    echo "PARAMETER|VALUE"
    # --- YOUR ORIGINAL LOGIC ---
    docker ps --filter "name=nano-node" --format "Name|Nano Node\nCreated Since|{{.RunningFor}}\nConcurrent Uptime|{{.Status}}" | sed 's/Up //'
    m=$(wc -l < /home/nano-data/uptime_minutes.txt); echo "Cumulative Uptime|$((m/1440))d $((m%1440/60))h $((m%60))m"
    total_mins=$(( ($(date +%s) - $(date -d "$(docker inspect nano-node -f '{{.Created}}')" +%s)) / 60 ))
    python3 -c "print(f'Active Uptime %|{($m / $total_mins * 100):.2f}%')"
    stats=$(docker stats nano-node --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}")
    cpu_perc=$(echo $stats | cut -d'|' -f1 | tr -d '%'); mem_usage=$(echo $stats | cut -d'|' -f2 | sed 's/GiB/ GB/g; s/MiB/ MB/g')
    max_ghz=$(lscpu | grep "max MHz" | awk '{print $4/1000 " GHz"}' || echo "N/A"); physical_cores=$(lscpu -p | grep -v '^#' | sort -u -t, -k 2,4 | wc -l)
    sys_total=$(free -g | awk '/^Mem:/{print $2}')
    python3 -c "perc=$cpu_perc; cores=$physical_cores; max_g='$max_ghz'; ram_str='$mem_usage'; sys_tot=$sys_total;
parts=ram_str.split(); val=float(parts[0]); unit=parts[1];
ram_gb = val if unit=='GB' else val/1024
total_impact = ram_gb + (sys_tot * 0.25)
cpu_w=(cores*5)*(perc/100); ram_w=total_impact*1.5; 
print(f'CPU Usage|{(perc/100 * float(max_g.split()[0])):.2f} GHz / {max_g}\nCPU Core Usage|{max(0.01, round(perc/100, 2))} core / {cores} cores\nRAM Usage|{ram_str}\nPower Consumption (Est.)|{(cpu_w + ram_w):.2f} Watts (Incl. Ledger Cache Overhead)')"
    IFACE=$(ip route get 1.1.1.1 | awk '{print $5}'); read rx1 tx1 < <(awk -v iface="$IFACE" '$1 ~ iface {print $2,$10}' /proc/net/dev); sleep 1; read rx2 tx2 < <(awk -v iface="$IFACE" '$1 ~ iface {print $2,$10}' /proc/net/dev)
    echo "Internet Usage|$(echo "scale=1; ($rx2-$rx1)*8/1048576" | bc) Mbps Down / $(echo "scale=1; ($tx2-$tx1)*8/1048576" | bc) Mbps Up"
    tel=$(curl -s -d '{"action":"telemetry"}' http://localhost:7076)
    echo "Block Count|$(echo "$tel" | grep -oP '\"block_count\":\s*\"\K\d+')"
    echo "Peer Count|$(echo "$tel" | grep -oP '\"peer_count\":\s*\"\K\d+')"
    v_maj=$(echo "$tel" | grep -oP '\"major_version\":\s*\"\K\d+'); v_min=$(echo "$tel" | grep -oP '\"minor_version\":\s*\"\K\d+'); v_pat=$(echo "$tel" | grep -oP '\"patch_version\":\s*\"\K\d+')
    echo "Node Version|$v_maj.$v_min.$v_pat"
    b_cap=$(echo "$tel" | grep -oP '\"bandwidth_cap\":\s*\"\K\d+'); echo "Bandwidth Cap|$((b_cap/1048576)) MB/s"
    echo "Node ID|$(echo "$tel" | grep -oP '\"node_id\":\s*\"\K[^"]+')"
    # --- END OF ORIGINAL LOGIC ---
  } | column -t -s "|"

  echo "---------------------------------------------------------------"
  echo " Auto-refreshing every 30 seconds. Press [CTRL+C] to stop"
  echo " Your Nano node will keep running even if you stop dashboard"
  echo " To check dashboard again (if stopped) just type dashboard.sh"
  echo "==============================================================="
}

# The loop to refresh the dashboard
while true; do
  run_dashboard
  sleep 30
done
