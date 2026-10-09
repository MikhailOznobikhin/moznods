#!/bin/sh
# One-time bootstrap of a fresh Ubuntu VPS for docker-compose.production.yml.
# Run as root: sh docker/server-setup.sh
# Safe to re-run. Does not touch SSH settings (see docs/infrastructure.md).
set -eu

SWAP_SIZE="${SWAP_SIZE:-2G}"

echo "== swap ($SWAP_SIZE)"
# Skip when any swap is already active (the Ubuntu installer often creates /swap.img).
if [ -z "$(swapon --noheadings)" ]; then
  fallocate -l "$SWAP_SIZE" /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
# Use swap only as a safety net against OOM, not as working memory.
cat > /etc/sysctl.d/99-moznods.conf <<'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
# Recommended by Redis.
vm.overcommit_memory=1
# Larger UDP buffers for LiveKit media.
net.core.rmem_max=5000000
net.core.wmem_max=5000000
EOF
sysctl --system >/dev/null

echo "== packages"
apt-get update
apt-get install -y ca-certificates curl ufw fail2ban unattended-upgrades certbot make git

echo "== docker"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi
# Cap logs of containers started without an explicit logging section.
if [ ! -f /etc/docker/daemon.json ]; then
  cat > /etc/docker/daemon.json <<'EOF'
{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "3"}}
EOF
  systemctl restart docker
fi

echo "== firewall"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
# LiveKit (see docker-compose.production.yml).
ufw allow 7881/tcp
ufw allow 7882:7883/udp
ufw allow 3478/udp
ufw allow 5349/tcp
ufw --force enable

echo "== automatic security updates"
dpkg-reconfigure -f noninteractive unattended-upgrades
systemctl enable --now fail2ban

echo "Done. Next: SSH keys only, .env, certbot, make deploy (docs/infrastructure.md)."
