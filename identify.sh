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
if [ -n "$model" ]; then
    echo "  Model: $model"
elif [ -d /sys/class/dmi/id ]; then
    # x86/PC: use DMI (SMBIOS) info
    vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr -d '\n')
    product=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr -d '\n')
    board=$(cat /sys/class/dmi/id/board_name 2>/dev/null | tr -d '\n')
    [ -n "$vendor" ] && [ -n "$product" ] && echo "  System: $vendor $product"
    [ -n "$board" ] && [ "$board" != "Default string" ] && echo "  Board: $board"
fi
if [ -f /etc/armbian-release ]; then
    . /etc/armbian-release 2>/dev/null
    [ -n "$BOARD" ] && echo "  Board: $BOARD"
fi
if [ -f /proc/cpuinfo ]; then
    cpu=$(grep -m1 "Hardware" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
    [ -n "$cpu" ] && echo "  Hardware: $cpu"
fi
[ -z "$model" ] && [ -z "$vendor" ] && echo "  (Generic $(uname -m) system)"
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
root_dev=$(findmnt -n -o SOURCE / 2>/dev/null)
[ -z "$root_dev" ] && root_dev=$(df / 2>/dev/null | tail -1 | awk '{print $1}')

# Trace LVM/RAID/mapper back to the physical disk
base_dev=""
# Method 1: lsblk -s shows inverse tree (device -> parents -> disk)
if command -v lsblk &>/dev/null && [ -n "$root_dev" ]; then
    base_dev=$(lsblk -s -o NAME,TYPE -n "$root_dev" 2>/dev/null | awk '$2=="disk" {d=$1} END {print d}')
fi
# Method 2: sysfs walk (works when lsblk -s fails)
if [ -z "$base_dev" ] && [ -n "$root_dev" ]; then
    current=$(basename "$(readlink -f "$root_dev" 2>/dev/null)" 2>/dev/null)
    while [ -n "$current" ]; do
        if [ -e "/sys/block/$current" ]; then
            base_dev="$current"
            break
        fi
        if [ -d "/sys/class/block/$current/slaves" ]; then
            current=$(ls /sys/class/block/$current/slaves/ 2>/dev/null | head -1)
        elif [ -e "/sys/class/block/$current/.." ]; then
            current=$(basename "$(readlink -f /sys/class/block/$current/.. 2>/dev/null)" 2>/dev/null)
        else
            break
        fi
    done
fi
[ -z "$base_dev" ] && base_dev=$(basename "$root_dev" 2>/dev/null | sed 's/[0-9]*$//' | sed 's/p$//')

storage_type=""
if [ -n "$base_dev" ]; then
    if [[ "$base_dev" == mmcblk* ]]; then
        stype=$(cat /sys/block/$base_dev/device/type 2>/dev/null)
        if [ "$stype" = "SD" ]; then
            storage_type="SD Card"
        elif [ "$stype" = "MMC" ]; then
            storage_type="eMMC"
        elif [[ "$base_dev" == mmcblk0 ]]; then
            storage_type="eMMC (likely)"
        elif [[ "$base_dev" == mmcblk1 ]]; then
            storage_type="SD Card (likely)"
        else
            storage_type="MMC (SD/eMMC)"
        fi
    elif [[ "$base_dev" == nvme* ]]; then
        storage_type="NVMe SSD"
    elif [[ "$base_dev" == sd* ]]; then
        rota=$(cat /sys/block/$base_dev/queue/rotational 2>/dev/null)
        [ "$rota" = "0" ] && storage_type="SSD"
        [ "$rota" = "1" ] && storage_type="HDD"
        [ -z "$storage_type" ] && storage_type="USB/Removable"
    else
        storage_type="$base_dev"
    fi
fi
[ -z "$storage_type" ] && storage_type="Unknown"
echo "  Running on: $storage_type"

if command -v lsblk &>/dev/null && [ -n "$base_dev" ]; then
    size=$(lsblk -b -d -n -o SIZE "/dev/$base_dev" 2>/dev/null | head -1)
    if [ -n "$size" ]; then
        size_gb=$((size / 1024 / 1024 / 1024))
        echo "  Size: ${size_gb} GB"
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
