#!/bin/bash
set -e

echo "=== System Test Script ==="
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime)"
echo ""

echo "=== Testing disk mounts ==="
df -h | grep -E '(Filesystem|/dev/vda)'
echo ""

echo "=== Testing btrfs subvolumes ==="
sudo btrfs subvolume list /
echo ""

echo "=== Testing user configuration ==="
whoami
id
echo ""

echo "=== Testing network configuration ==="
ip addr show
echo ""

echo "=== Testing systemd services ==="
systemctl is-active systemd-networkd
systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null || echo "SSH service not found"
echo ""

echo "=== All tests passed! ==="
