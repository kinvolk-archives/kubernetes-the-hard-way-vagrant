#!/bin/bash

set -euo pipefail

cat <<EOF | sudo tee -a /etc/hosts

# KTHW Vagrant machines
192.168.199.10 controller-0
192.168.199.11 controller-1
192.168.199.12 controller-2
192.168.199.20 worker-0
192.168.199.21 worker-1
192.168.199.22 worker-2
EOF

# This is added to get around the DNS issue in Ubuntu
# See https://github.com/kubernetes/kubernetes/issues/66067
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
