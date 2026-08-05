#!/bin/bash
# vpn-route-check.sh — 网络层只读诊断（v0.1）
#
# 作用：
#   - 看 WSL 端当前路由表
#   - 看 Sangfor 推的路由（开 / 关对比）
#   - 看 Windows 端 DNS / Clash / Litellm 状态
#   - 不修改任何东西（pure read-only）
#
# 用法：
#   bash ~/infra/network/vpn-route-check.sh                # 一次快照
#   bash ~/infra/network/vpn-route-check.sh --sangfor-on  # 启 Sangfor 后跑
#   bash ~/infra/network/vpn-route-check.sh --sangfor-off # 关 Sangfor 后跑
#   bash ~/infra/network/vpn-route-check.sh --diff       # 对比两次输出

set -e
DATE=$(date '+%Y-%m-%d %H:%M:%S')
TAG="${1:-snapshot}"

echo "================================================"
echo "VPN Route Check — $DATE"
echo "Tag: $TAG"
echo "================================================"
echo ""

echo "── 1. WSL 端路由表（当前）──"
ip route
echo ""

echo "── 2. WSL 端 DNS 配置 ──"
cat /etc/resolv.conf 2>/dev/null | grep -v '^#'
echo ""

echo "── 3. WSL 端 默认出口 (default route) ──"
ip route | grep '^default' | head -3
echo ""

echo "── 4. WSL 端 /etc/hosts 静态解析 ──"
grep -v '^#' /etc/hosts 2>/dev/null | grep -v '^$' | head -10
echo ""

echo "── 5. Clash 端口 7897 (WSL 端 127.0.0.1) ──"
timeout 3 bash -c 'echo > /dev/tcp/127.0.0.1/7897 && echo "7897 OK" || echo "7897 CLOSED"' 2>&1
echo ""

echo "── 6. Litellm 端口 4000 (WSL 端 127.0.0.1) ──"
curl -s -m 3 http://127.0.0.1:4000/health/liveliness 2>&1 | head -3
echo ""

echo "── 7. Windows 端 关键服务进程 ──"
powershell.exe -NoProfile -Command '
$clash = Get-Process -Name "Clash Verge*" -ErrorAction SilentlyContinue | Select-Object -First 1
$sangfor = Get-Process -Name "Sangfor*" -ErrorAction SilentlyContinue | Select-Object -First 1
$litellm = (docker ps --filter "name=hermes-litellm" --format "{{.Names}}" 2>$null)

Write-Host "Clash Verge:   $(if ($clash) {"Running PID=$($clash.Id)"} else {"NOT RUNNING"})"
Write-Host "Sangfor:       $(if ($sangfor) {"Running PID=$($sangfor.Id)"} else {"NOT RUNNING"})"
Write-Host "Litellm:       $(if ($litellm) {"Container UP"} else {"NOT RUNNING"})"
' 2>&1 | head -10
echo ""

echo "── 8. Windows 端 DNS resolver ──"
powershell.exe -NoProfile -Command "Get-DnsClientServerAddress -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses" 2>&1 | head -10
echo ""

echo "── 9. TCP 出公网测试（WSL 端 socket）──"
for host_port in "8.8.8.8:53" "1.1.1.1:53" "60.28.220.199:443" "127.0.0.1:7897" "127.0.0.1:4000"; do
  host=$(echo $host_port | cut -d: -f1)
  port=$(echo $host_port | cut -d: -f2)
  result=$(timeout 3 bash -c "echo > /dev/tcp/$host/$port && echo OK" 2>&1 || echo "FAIL/NO_ROUTE")
  printf "  %-22s %s\n" "$host_port" "$result"
done
echo ""

echo "── 10. Sangfor 推的路由（如果有 eth3）──"
if ip link show eth3 &>/dev/null; then
  echo "eth3 interface EXISTS — Sangfor probably active"
  ip route | grep "via.*dev eth3" | head -10
else
  echo "eth3 interface NOT FOUND — Sangfor probably inactive"
fi
echo ""

echo "── 11. Litellm 容器能直连上游（60.28.220.199:443）──"
sg docker -c "docker exec hermes-litellm python3 -c 'import socket; s=socket.create_connection((\"60.28.220.199\", 443), timeout=5); s.close(); print(\"OK\")' 2>&1" | head -3
echo ""

echo "================================================"
echo "Tip: 跑两次用 --diff 对比，看 Sangfor 开 / 关的路由差异"
echo "================================================"
