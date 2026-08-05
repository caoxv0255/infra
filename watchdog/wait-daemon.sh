#!/bin/bash
# Watchdog: 等 docker daemon 就绪，自动 pull 镜像
LOG=/home/cx/infra/watchdog/watchdog.log
echo "[$(date '+%H:%M:%S')] watchdog started" > "$LOG"

while true; do
  if sg docker -c 'docker info 2>&1 | grep -q "Server Version"' 2>/dev/null; then
    NOW=$(date '+%H:%M:%S')
    echo "[$NOW] daemon READY" >> "$LOG"
    cd /home/cx/infra
    echo "[$NOW] starting pull..." >> "$LOG"
    sg docker -c 'docker compose pull' >> "$LOG" 2>&1
    echo "[$NOW] pull exit: $?" >> "$LOG"
    sg docker -c 'docker images | grep litellm' >> "$LOG"
    exit 0
  fi
  sleep 10
done
