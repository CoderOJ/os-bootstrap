set -eou pipefail

sudo tee /etc/modprobe.d/blacklist-nouveau.conf <<EOF
blacklist nouveau
options nouveau modeset=0
EOF

sudo apt install linux-headers-amd64
sudo apt install nvidia-driver nvidia-persistenced
