#!/bin/bash
set -e

ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# ─── CHECK FOR DOCKER ─────────────────────────────────────────────────────
echo -e "${ORANGE}🔍 Checking for Docker installation...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${ORANGE}📦 Docker not found. Installing...${NC}"
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo -e "${ORANGE}✅ Docker is already installed.${NC}"
fi

# ─── CHECK AND FREE PORTS ─────────────────────────────────────────────────
echo -e "${ORANGE}🔍 Checking if ports 80 and 443 are available...${NC}"
for PORT in 80 443; do
    if lsof -i :$PORT &>/dev/null; then
        echo -e "${ORANGE}⚠️ Port $PORT is in use. Killing the process...${NC}"
        fuser -k ${PORT}/tcp || true
    else
        echo -e "${ORANGE}✅ Port $PORT is free.${NC}"
    fi
done

# ─── PREPARE SYSCTL AND LIMITS ────────────────────────────────────────────
echo -e "${ORANGE}📜 Applying system tuning...${NC}"
cat <<EOF | sudo tee /etc/sysctl.d/99-popcache.conf
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
EOF

sudo sysctl -p /etc/sysctl.d/99-popcache.conf

cat <<EOF | sudo tee /etc/security/limits.d/popcache.conf
*    hard nofile 65535
*    soft nofile 65535
EOF

# ─── ASK USER FOR CONFIG ──────────────────────────────────────────────────
echo -e "${ORANGE}🧩 Let's configure your PoP Node...${NC}"
read -p "Enter your POP name: " POP_NAME

LOCATION=$(curl -s https://ipinfo.io/json | jq -r '.region + ", " + .country')
echo -e "${ORANGE}🌍 Auto-detected location: $LOCATION${NC}"

read -p "Enter memory cache size in MB (Default: 4096Mb Just click Enter): " MEMORY_MB
MEMORY_MB=${MEMORY_MB:-4096}
DISK_FREE=$(df -h / | awk 'NR==2{print $4}')
read -p "Enter disk cache size in GB [Default: 100Gb Just click Enter] (Free on server: $DISK_FREE): " DISK_GB
DISK_GB=${DISK_GB:-100}

read -p "Enter your node name (EN): " NODE_NAME
read -p "Enter your name (EN): " NAME
read -p "Enter your email: " EMAIL
read -p "Enter your Discord username: " DISCORD
read -p "Enter your Telegram username: " TELEGRAM
read -p "Enter your Solana wallet address: " SOLANA
read -p "Enter your POP_INVITE_CODE: " INVITE_CODE

# ─── PREPARE DIRECTORY ────────────────────────────────────────────────────
echo -e "${ORANGE}📁 Setting up /opt/popcache...${NC}"
sudo mkdir -p /opt/popcache
cd /opt/popcache
sudo chmod 777 /opt/popcache

# ─── DOWNLOAD PoP BINARY ──────────────────────────────────────────────────
echo -e "${ORANGE}⬇️ Downloading PoP binary...${NC}"
wget -q https://download.pipe.network/static/pop-v0.3.0-linux-x64.tar.gz
tar -xzf pop-v0.3.0-linux-*.tar.gz
chmod 755 pop

# ─── CREATE CONFIG.JSON ───────────────────────────────────────────────────
cat <<EOF > config.json
{
  "pop_name": "$POP_NAME",
  "pop_location": "$LOCATION",
  "server": {
    "host": "0.0.0.0",
    "port": 443,
    "http_port": 80,
    "workers": 0
  },
  "cache_config": {
    "memory_cache_size_mb": $MEMORY_MB,
    "disk_cache_path": "./cache",
    "disk_cache_size_gb": $DISK_GB,
    "default_ttl_seconds": 86400,
    "respect_origin_headers": true,
    "max_cacheable_size_mb": 1024
  },
  "api_endpoints": {
    "base_url": "https://dataplane.pipenetwork.com"
  },
  "identity_config": {
    "node_name": "$NODE_NAME",
    "name": "$NAME",
    "email": "$EMAIL",
    "website": "https://your-website.com",
    "discord": "$DISCORD",
    "telegram": "$TELEGRAM",
    "solana_pubkey": "$SOLANA"
  }
}
EOF

# ─── CREATE DOCKERFILE ────────────────────────────────────────────────────
cat <<EOF > Dockerfile
FROM ubuntu:24.04

RUN apt update && apt install -y \\
    ca-certificates \\
    curl \\
    libssl-dev \\
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/popcache

COPY pop .
COPY config.json .

RUN chmod +x ./pop

CMD ["./pop", "--config", "config.json"]
EOF

# ─── APPLY FILE DESCRIPTOR LIMIT ──────────────────────────────────────────
echo -e "${ORANGE}🔧 Applying file descriptor limit for current shell (ulimit)...${NC}"
ulimit -n 65535 || echo -e "${ORANGE}⚠️ ulimit couldn't be changed. You may need to relogin.${NC}"

# ─── BUILD AND RUN DOCKER CONTAINER ───────────────────────────────────────
echo -e "${ORANGE}🏗️ Building Docker image...${NC}"
docker build -t popnode .

echo -e "${ORANGE}🚀 Launching container...${NC}"
docker run -d \
  --name popnode \
  -p 80:80 \
  -p 443:443 \
  -v /opt/popcache:/app \
  -w /app \
  -e POP_INVITE_CODE=$INVITE_CODE \
  --restart unless-stopped \
  popnode

# ─── SHOW ACCESS COMMANDS ─────────────────────────────────────────────────
IP=$(curl -s https://ipinfo.io/ip)
echo -e "${ORANGE}✅ Setup complete!${NC}"
echo -e "${ORANGE}📦 View logs:${NC} docker logs -f popnode"
echo -e "${ORANGE}🧪 Check health in browser:${NC} http://$IP/health"
echo -e "${ORANGE}🔒 Check secure status:${NC} https://$IP/state"
echo -e "${ORANGE}💾 Important: Save your identity backup file:${NC} /opt/popcache/.pop_state.json"
echo -e "${ORANGE}🔒 This file contains your node identity. Back it up securely!${NC}"
echo -e "${ORANGE}📦 To change or view the configuration file:${NC} nano /opt/popcache/config.json"
