#!/bin/bash
# network-status.sh — Day 0 系统化网络只读观测（v0.1）
#
# 作用：
#   - 5 个 section 完整快照：ROUTE / DNS / PROXY / VPN / DOCKER
#   - 不修改任何东西（pure read-only）
#   - 输出可贴到 git commit message 留"网络审计日志"
#
# 用法：
#   bash ~/infra/network/network-status.sh           # 当前快照（无标签）
#   bash ~/infra/network/network-status.sh baseline  # 重置 baseline
#   bash ~/infra/network/network-status.sh before    # 当前 vs baseline
#   bash ~/infra/network/network-status.sh after     # 当前 vs baseline
#   bash ~/infra/network/network-status.sh diff      # 同 after

set -e
DATE=$(date '+%Y-%m-%d %H:%M:%S')
TAG="${1:-snapshot}"
SNAPSHOT_DIR="/home/cx/infra/network/snapshots"
SNAPSHOT="$SNAPSHOT_DIR/$DATE-$TAG.txt"

mkdir -p "$SNAPSHOT_DIR"

# 采集快照到文件
{
echo "===== NETWORK STATUS SNAPSHOT — $DATE (tag: $TAG) ====="
echo ""
echo "===== 1. ROUTE ====="
echo "── WSL 路由表 ──"
ip route
echo ""
echo "── 默认出口 (default route) ──"
ip route | grep '^default' | head -3
echo ""

echo "===== 2. DNS ====="
echo "── WSL /etc/resolv.conf ──"
grep -v '^#' /etc/resolv.conf 2>/dev/null | grep -v '^$'
echo ""
echo "── WSL /etc/hosts (非空行) ──"
grep -v '^#' /etc/hosts 2>/dev/null | grep -v '^$' | head -10
echo ""
echo "── Windows 端 DNS resolver ──"
powershell.exe -NoProfile -Command "Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses -Unique" 2>&1 | head -10
echo ""

echo "===== 3. PROXY ====="
echo "── WSL shell HTTP_PROXY env ──"
bash -i -c 'echo "http_proxy=$http_proxy"; echo "https_proxy=$https_proxy"; echo "HTTP_PROXY=$HTTP_PROXY"; echo "all_proxy=$all_proxy"; echo "no_proxy=$no_proxy"' 2>&1 | grep -E "proxy="
echo ""
echo "── Clash 端点 (Windows Clash Verge 7897) ──"
timeout 3 bash -c 'echo > /dev/tcp/127.0.0.1/7897 && echo "7897 OK" || echo "7897 CLOSED"' 2>&1
echo ""
echo "── Litellm 端点 (4000) ──"
curl -s -m 3 http://127.0.0.1:4000/health/liveliness 2>&1 | head -3
echo ""

echo "===== 4. VPN (Sangfor) ====="
echo "── Sangfor 进程 ──"
ps -ef 2>/dev/null | grep -i sangfor | grep -v grep | head -5 || echo "(no sangfor process)"
echo ""
echo "── WSL Sangfor 路由 (via eth3) ──"
ip route | grep "via.*dev eth3" | head -5 || echo "(no sangfor route)"
echo ""
echo "── Sangfor 路由总数 ──"
echo "  $(ip route | grep -c "via.*dev eth3") 条"
echo ""

echo "===== 5. DOCKER ====="
echo "── Litellm 容器状态 ──"
sg docker -c "docker ps --filter name=hermes-litellm --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>&1 | head -3
echo ""
echo "── Litellm 容器内 DNS (api.minimaxi.com) ──"
sg docker -c "docker exec hermes-litellm python3 -c 'import socket; print(socket.gethostbyname(\"api.minimaxi.com\"))'" 2>&1
echo ""
echo "── Litellm 容器内 HTTPS (60.28.220.199:443) ──"
sg docker -c "docker exec hermes-litellm python3 -c 'import socket; s=socket.create_connection((\"60.28.220.199\", 443), timeout=5); s.close(); print(\"OK\")'" 2>&1
echo ""

echo "===== 6. TCP 出公网测试（WSL 端） ====="
for host_port in "8.8.8.8:53" "1.1.1.1:53" "60.28.220.199:443" "127.0.0.1:7897" "127.0.0.1:4000"; do
  host=$(echo $host_port | cut -d: -f1)
  port=$(echo $host_port | cut -d: -f2)
  result=$(timeout 3 bash -c "echo > /dev/tcp/$host/$port && echo OK" 2>&1 || echo "FAIL/NO_ROUTE")
  printf "  %-22s %s\n" "$host_port" "$result"
done
echo ""

echo "===== END ====="
} > "$SNAPSHOT" 2>&1

# 打印
cat "$SNAPSHOT"
echo ""
echo "(Saved to: $SNAPSHOT)"

# Diff 模式
if [ "$TAG" = "before" ] || [ "$TAG" = "after" ]; then
  BASELINE=$(ls -t $SNAPSHOT_DIR/*-baseline.txt 2>/dev/null | head -1)
  if [ -n "$BASELINE" ]; then
    echo ""
    echo "===== DIFF vs $BASELINE ====="
    diff "$BASELINE" "$SNAPSHOT" | head -100
  else
    echo ""
    echo "(No baseline found, run 'network-status.sh baseline' first to set)"
  fi
fi
