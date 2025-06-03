#!/bin/bash

NODE_DIR="/opt/popcache"

INVITE_CODE=$(docker exec popnode env | grep POP_INVITE_CODE | cut -d '=' -f2)

echo "POP_INVITE_CODE=$INVITE_CODE" > "$NODE_DIR/pop.env"

docker stop popnode
docker rm popnode
docker rmi popnode

cd "$NODE_DIR"

rm -f pop-v0.3.0-linux-x64.tar.gz pop .pop_state.json .pop_state.json.bak

wget -q https://download.pipe.network/static/pop-v0.3.1-linux-x64.tar.gz
tar -xzf pop-v0.3.1-linux-x64.tar.gz
chmod 755 pop

cat > Dockerfile << EOL
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY pop .
COPY config.json .

RUN chmod +x ./pop

ENTRYPOINT ["./pop"]
CMD []
EOL

docker build -t popnode .

docker run -d \
  --name popnode \
  -p 80:80 \
  -p 443:443 \
  -v "$NODE_DIR":/app \
  -w /app \
  --env-file "$NODE_DIR/pop.env" \
  -e POP_CONFIG_PATH=/app/config.json \
  --restart unless-stopped \
  popnode

docker logs -f popnode
