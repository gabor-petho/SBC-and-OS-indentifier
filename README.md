# SBC and OS Identifier

A single script that gathers and prints key system information for Single Board Computers (SBCs) running Linux.

## Usage

```bash
./identify.sh
```

Or if not executable:

```bash
bash identify.sh
```

## Output

The script prints:

- **SBC/Board** – Model (from device tree), board name (Armbian), hardware
- **OS** – Distro name, version, kernel, architecture
- **Storage** – Type (SD card, eMMC, SSD, NVMe, HDD), size, root usage
- **Memory** – Total, used, free, usage %
- **Other** – Hostname, uptime, CPU cores, CPU temperature

## Requirements

- Linux (bash)
- Uses standard tools: `lsblk`, `findmnt`, `df`, `grep`, etc.
- Works on Raspberry Pi, Orange Pi, Rockchip boards, Armbian, and most Linux SBCs
