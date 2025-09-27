#!/bin/bash
# tcping.sh - Pure Bash + nc TCP ping with colorful statistics + reliable uptime/downtime
# Usage: ./tcping.sh [-4|-6] host port [count]
# Requires: nc (netcat-openbsd), awk, date (GNU coreutils)

# ANSI 颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
MAGENTA="\033[35m"
RESET="\033[0m"

force_ip=""
if [[ $1 == "-4" ]]; then
    force_ip="-4"; shift
elif [[ $1 == "-6" ]]; then
    force_ip="-6"; shift
fi

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 [-4|-6] host port [count]"
    exit 1
fi

host=$1
port=$2
count=${3:-4}  # default 4 probes

# statistics
success=0
fail=0
rtts=()

start_epoch=$(date +%s)
start_time_human=$(date -d "@$start_epoch" "+%Y-%m-%d %H:%M:%S")

# uptime/downtime trackers (use epoch seconds)
total_uptime=0
total_downtime=0
longest_up=0
longest_down=0
current_up=0
current_down=0
current_up_start_epoch=0
current_down_start_epoch=0
longest_up_start_epoch=0
longest_up_end_epoch=0
longest_down_start_epoch=0
longest_down_end_epoch=0
last_success_epoch=0
last_fail_epoch=0

# helper to format seconds to "X minutes Y seconds"
sec_min_sec() {
    s=$1
    printf "%d minutes %d seconds" $((s/60)) $((s%60))
}

# print statistics on exit
print_stats() {
    end_epoch=$(date +%s)
    end_time_human=$(date -d "@$end_epoch" "+%Y-%m-%d %H:%M:%S")
    duration=$((end_epoch - start_epoch))

    total=$((success + fail))
    loss_percent=$(awk -v f="$fail" -v t="$total" 'BEGIN{if(t>0) printf "%.2f", 100*f/t; else print "0.00"}')

    echo
    echo -e "${YELLOW}--- $host TCPing statistics ---${RESET}"
    echo -e "$total probes transmitted on port $port | ${GREEN}$success received${RESET}, ${RED}${loss_percent}% packet loss${RESET}"
    echo -e "successful probes: ${GREEN}$success${RESET}"
    echo -e "unsuccessful probes: ${RED}$fail${RESET}"

    # last success/fail human readable
    if (( last_success_epoch > 0 )); then
        last_success_time=$(date -d "@$last_success_epoch" "+%Y-%m-%d %H:%M:%S")
    else
        last_success_time="N/A"
    fi
    if (( last_fail_epoch > 0 )); then
        last_fail_time=$(date -d "@$last_fail_epoch" "+%Y-%m-%d %H:%M:%S")
    else
        last_fail_time="N/A"
    fi

    echo -e "last successful probe: ${CYAN}${last_success_time}${RESET}"
    echo -e "last unsuccessful probe: ${CYAN}${last_fail_time}${RESET}"
    echo -e "total uptime:   ${GREEN}$(sec_min_sec $total_uptime)${RESET}"
    echo -e "total downtime: ${RED}$(sec_min_sec $total_downtime)${RESET}"

    if (( longest_up > 0 )); then
        up_start=$(date -d "@$longest_up_start_epoch" "+%Y-%m-%d %H:%M:%S")
        up_end=$(date -d "@$longest_up_end_epoch" "+%Y-%m-%d %H:%M:%S")
        echo -e "longest consecutive uptime:   ${GREEN}${longest_up} seconds${RESET} from ${CYAN}${up_start}${RESET} to ${CYAN}${up_end}${RESET}"
    else
        echo -e "longest consecutive uptime:   ${GREEN}N/A${RESET}"
    fi

    if (( longest_down > 0 )); then
        down_start=$(date -d "@$longest_down_start_epoch" "+%Y-%m-%d %H:%M:%S")
        down_end=$(date -d "@$longest_down_end_epoch" "+%Y-%m-%d %H:%M:%S")
        echo -e "longest consecutive downtime: ${RED}${longest_down} seconds${RESET} from ${CYAN}${down_start}${RESET} to ${CYAN}${down_end}${RESET}"
    else
        echo -e "longest consecutive downtime: ${RED}N/A${RESET}"
    fi

    if (( success > 0 )); then
        min=$(printf "%s\n" "${rtts[@]}" | sort -n | head -1)
        max=$(printf "%s\n" "${rtts[@]}" | sort -n | tail -1)
        sum=0
        for r in "${rtts[@]}"; do (( sum += r )); done
        avg=$(awk -v s="$sum" -v n="$success" 'BEGIN{if(n>0) printf "%.3f", s/n; else print "0"}')
        echo -e "rtt ${MAGENTA}min/avg/max${RESET}: ${CYAN}${min}${RESET}/${CYAN}${avg}${RESET}/${CYAN}${max}${RESET} ms"
    fi

    echo "-----------------------------------"
    echo -e "TCPing started at: ${CYAN}$start_time_human${RESET}"
    echo -e "TCPing ended at:   ${CYAN}$end_time_human${RESET}"
    printf "duration (HH:MM:SS): ${CYAN}%02d:%02d:%02d${RESET}\n" \
        $((duration/3600)) $((duration%3600/60)) $((duration%60))
}

trap print_stats EXIT

# main loop
for ((i=1; i<=count || count==0; i++)); do
    now_epoch=$(date +%s)
    now_human=$(date -d "@$now_epoch" "+%Y-%m-%d %H:%M:%S")
    t1=$(date +%s%3N)
    if nc $force_ip -z -w 3 "$host" "$port" 2>/dev/null; then
        t2=$(date +%s%3N)
        rtt=$((t2 - t1))
        echo -e "${GREEN}Connected${RESET} to $host:$port, seq=$i time=${CYAN}${rtt}ms${RESET}"
        rtts+=($rtt)
        ((success++))
        last_success_epoch=$now_epoch

        # uptime update
        if (( current_up == 0 )); then
            current_up_start_epoch=$now_epoch
        fi
        current_up=$((current_up+1))
        total_uptime=$((total_uptime+1))
        # update longest consecutive uptime
        if (( current_up > longest_up )); then
            longest_up=$current_up
            longest_up_start_epoch=$current_up_start_epoch
            longest_up_end_epoch=$now_epoch
        fi
        # reset down counter
        current_down=0
    else
        echo -e "${RED}Connection to $host:$port failed, seq=$i${RESET}"
        ((fail++))
        last_fail_epoch=$now_epoch

        # downtime update
        if (( current_down == 0 )); then
            current_down_start_epoch=$now_epoch
        fi
        current_down=$((current_down+1))
        total_downtime=$((total_downtime+1))
        if (( current_down > longest_down )); then
            longest_down=$current_down
            longest_down_start_epoch=$current_down_start_epoch
            longest_down_end_epoch=$now_epoch
        fi
        # reset up counter
        current_up=0
    fi
    sleep 1
done
