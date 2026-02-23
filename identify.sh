#!/bin/bash
# SBC and OS Identifier - Gathers system info in one run
# Usage: ./identify.sh   or   bash identify.sh

echo "=========================================="
echo "       SBC & OS System Report"
echo "=========================================="
echo ""

# --- SBC / Board identification ---
echo "SBC / Board:"
model=""
[ -f /proc/device-tree/model ] && model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
[ -z "$model" ] && [ -f /sys/firmware/devicetree/base/model ] && model=$(tr -d '\0' < /sys/firmware/devicetree/base/model 2>/dev/null)
[ -n "$model" ] && echo "  Model: $model"
if [ -f /etc/armbian-release ]; then
    . /etc/armbian-release 2>/dev/null
    [ -n "$BOARD" ] && echo "  Board: $BOARD"
fi
if [ -f /proc/cpuinfo ]; then
    cpu=$(grep -m1 "Hardware" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
    [ -n "$cpu" ] && echo "  Hardware: $cpu"
fi
echo ""

# --- OS ---
echo "OS:"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "  Name: $PRETTY_NAME"
    [ -n "$VERSION_ID" ] && echo "  Version: $VERSION_ID"
fi
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"
echo ""

# --- Storage ---
echo "Storage:"
if command -v lsblk &>/dev/null; then
    root_dev=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/[0-9]*$//' | sed 's/p$//')
    [ -z "$root_dev" ] && root_dev=$(df / 2>/dev/null | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//' | sed 's/p$//')
    
    if [ -n "$root_dev" ]; then
        base_dev=$(basename "$root_dev")
        stype=""
        # Detect storage type
        if [[ "$base_dev" == mmcblk* ]]; then
            if [ -d "/sys/block/$base_dev" ]; then
                if [ -f /sys/block/$base_dev/device/type ]; then
                    stype=$(cat /sys/block/$base_dev/device/type 2>/dev/null)
                fi
                if [ "$stype" = "SD" ]; then
                    echo "  Type: SD Card"
                elif [ "$stype" = "MMC" ]; then
                    echo "  Type: eMMC"
                elif [[ "$base_dev" == mmcblk0 ]]; then
                    echo "  Type: eMMC (likely)"
                elif [[ "$base_dev" == mmcblk1 ]]; then
                    echo "  Type: SD Card (likely)"
                else
                    echo "  Type: MMC (SD/eMMC)"
                fi
            fi
        elif [[ "$base_dev" == nvme* ]]; then
            echo "  Type: NVMe SSD"
        elif [[ "$base_dev" == sd* ]]; then
            rota=$(cat /sys/block/$base_dev/queue/rotational 2>/dev/null)
            [ "$rota" = "0" ] && echo "  Type: SSD"
            [ "$rota" = "1" ] && echo "  Type: HDD"
        fi
        size=$(lsblk -b -d -n -o SIZE "/dev/$base_dev" 2>/dev/null | head -1)
        if [ -n "$size" ]; then
            size_gb=$((size / 1024 / 1024 / 1024))
            echo "  Size: ${size_gb} GB"
        fi
    fi
fi
# Root filesystem usage (works even without lsblk)
echo "  Root usage: $(df -h / 2>/dev/null | tail -1 | awk '{print $3 " used / " $2 " total (" $5 " used)"}')"
echo ""

# --- Memory ---
echo "Memory:"
if [ -f /proc/meminfo ]; then
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    mem_avail=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    mem_used=$((mem_total - mem_avail))
    mem_total_mb=$((mem_total / 1024))
    mem_used_mb=$((mem_used / 1024))
    mem_avail_mb=$((mem_avail / 1024))
    echo "  Total: ${mem_total_mb} MB"
    echo "  Used:  ${mem_used_mb} MB"
    echo "  Free:  ${mem_avail_mb} MB"
    if [ "$mem_total" -gt 0 ]; then
        pct=$((mem_used * 100 / mem_total))
        echo "  Usage: ${pct}%"
    fi
fi
echo ""

# --- Extra useful info ---
echo "Other:"
echo "  Hostname: $(hostname 2>/dev/null)"
echo "  Uptime: $(uptime -p 2>/dev/null || uptime 2>/dev/null | cut -d, -f1)"
echo "  CPU cores: $(nproc 2>/dev/null)"
echo "  CPU temp: $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f°C\n", $1/1000}' || echo "N/A")"
echo ""
echo "=========================================="
