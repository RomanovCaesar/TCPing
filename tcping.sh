#!/bin/bash
# tcping.sh - Pure Bash + nc TCP ping with colorful statistics + uptime/downtime
# Usage: ./tcping.sh [-4|-6] host port [count]

# ANSI colours
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
MAGENTA="\033[35m"
RESET="\033[0m"

force_ip=""
if [[ $1 == "-4" ]]; then
    force_ip="-4"
    shift
elif [[ $1 == "-6" ]]; then
    force_ip="-6"
    shift
fi

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 [-4|-6] host port [count]"
    exit 1
fi

host=$1
port=$2
count=${3:-4}  # default 4 times

# statistics variables
success=0
fail=0
rtts=()
start_time_human=$(date "+%Y-%m-%d %H:%M:%S")
start_epoch=$(date +%s)

# uptime/downtime variables
total_uptime=0
total_downtime=0
longest_up=0
longest_down=0
current_up=0
current_down=0
last_success_time=""
last_fail_time=""
longest_up_start=""
longest_up_end=""
longest_down_start=""
longest_down_end=""

# print statistics on exit
print_stats() {
    end_time_human=$(date "+%Y-%m-%d %H:%M:%S")
    end_epoch=$(date +%s)
    duration=$((end_epoch - start_epoch))

    total=$((success + fail))
    if (( total > 0 )); then
        loss_percent=$(echo "scale=2; 100*$fail/$total" | bc)
    else
        loss_percent="0.00"
    fi

    echo
    echo -e "${YELLOW}--- $host TCPing statistics ---${RESET}"
    echo -e "$total probes transmitted on port $port | ${GREEN}$success received${RESET}, ${RED}${loss_percent}% packet loss${RESET}"
    echo -e "successful probes: ${GREEN}$success${RESET}"
    echo -e "unsuccessful probes: ${RED}$fail${RESET}"

    # uptime/downtime
    echo -e "last successful probe: ${CYAN}${last_success_time:-N/A}${RESET}"
    echo -e "last unsuccessful probe: ${CYAN}${last_fail_time:-N/A}${RESET}"
    echo -e "total uptime:   ${GREEN}$(printf "%d minutes %d seconds" $((total_uptime/60)) $((total_uptime%60)))${RESET}"
    echo -e "total downtime: ${RED}$(printf "%d minutes %d seconds" $((total_downtime/60)) $((total_downtime%60)))${RESET}"
    echo -e "longest consecutive uptime:   ${GREEN}$(printf "%d seconds" $longest_up)${RESET} from ${CYAN}${longest_up_start}${RESET} to ${CYAN}${longest_up_end}${RESET}"
    echo -e "longest consecutive downtime: ${RED}$(printf "%d seconds" $longest_down)${RESET} from ${CYAN}${longest_down_start}${RESET} to ${CYAN}${longest_down_end}${RESET}"

    if (( success > 0 )); then
        min=$(printf "%s\n" "${rtts[@]}" | sort -n | head -1)
        max=$(printf "%s\n" "${rtts[@]}" | sort -n | tail -1)
        sum=0
        for r in "${rtts[@]}"; do
            (( sum += r ))
        done
        avg=$(echo "scale=3; $sum / $success" | bc)
        echo -e "rtt ${MAGENTA}min/avg/max${RESET}: ${CYAN}${min}${RESET}/${CYAN}${avg}${RESET}/${CYAN}${max}${RESET} ms"
    fi

    echo "-----------------------------------"
    echo -e "TCPing started at: ${CYAN}$start_time_human${RESET}"
    echo -e "TCPing ended at:   ${CYAN}$end_time_human${RESET}"
    printf "duration (HH:MM:SS): ${CYAN}%02d:%02d:%02d${RESET}\n" \
        $((duration/3600)) $((duration%3600/60)) $((duration%60))
}

# trap Ctrl+C
trap print_stats EXIT

# main loop
for ((i=1; i<=count || count==0; i++)); do
    t1=$(date +%s%3N)
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    if nc $force_ip -z -w 3 "$host" "$port" 2>/dev/null; then
        t2=$(date +%s%3N)
        rtt=$((t2 - t1))
        echo -e "${GREEN}Connected${RESET} to $host:$port, seq=$i time=${CYAN}${rtt}ms${RESET}"
        rtts+=($rtt)
        ((success++))
        last_success_time=$ts

        # uptime/downtime update
        ((current_up++))
        total_uptime=$((total_uptime+1))
        if ((current_up > longest_up)); then
            longest_up=$current_up
            longest_up_end=$ts
            longest_up_start=$(date -d "$ts - $((current_up-1)) seconds" "+%Y-%m-%d %H:%M:%S")
        fi
        current_down=0
    else
        echo -e "${RED}Connection to $host:$port failed, seq=$i${RESET}"
        ((fail++))
        last_fail_time=$ts

        ((current_down++))
        total_downtime=$((total_downtime+1))
        if ((current_down > longest_down)); then
            longest_down=$current_down
            longest_down_end=$ts
            longest_down_start=$(date -d "$ts - $((current_down-1)) seconds" "+%Y-%m-%d %H:%M:%S")
        fi
        current_up=0
    fi
    sleep 1
done
