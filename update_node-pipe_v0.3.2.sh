#!/bin/bash

NODE_DIR="/opt/popcache"

INVITE_CODE=$(docker exec popnode env | grep POP_INVITE_CODE | cut -d '=' -f2)

if [ -z "$INVITE_CODE" ] && [ -f "$NODE_DIR/pop.env" ]; then
    INVITE_CODE=$(grep POP_INVITE_CODE "$NODE_DIR/pop.env" | cut -d '=' -f2)
fi

if [ -z "$INVITE_CODE" ]; then
    echo "Не удалось найти инвайт-код. Проверьте контейнер или файл pop.env."
    exit 1
fi

docker stop popnode
docker rm popnode
docker rmi popnode

cd "$NODE_DIR"

rm -f pop-v0.3.1-linux-x64.tar.gz pop .pop.lock ._pop

wget -q https://download.pipe.network/static/pop-v0.3.2-linux-x64.tar.gz
tar -xzf pop-v0.3.2-linux-x64.tar.gz

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
COPY .pop_state.json .
COPY .pop_state.json.bak .

RUN chmod 777 pop && chmod 666 config.json .pop_state.json .pop_state.json.bak

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
