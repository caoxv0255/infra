#!/bin/bash
# vpn-normal-on.sh — Day 1 改写 v4：状态确认模式（不删路由）
#
# 关键：Sangfor 关闭后 kernel 自动清理 tunnel routes
#       手动 del 219.224 是冗余的
#
# 改写后只做：
#   1. 检查 tunnel 已断
#   2. 检查默认路由仍走 eth0（家用）
#   3. 检查 Clash 端点（如需要）
#   4. 输出状态

set -e
SANGFOR_TEST_HOST="219.224.3.96"

echo "================================================"
echo "校园 VPN 关闭后状态确认 — $(date '+%H:%M:%S')"
echo "================================================"

# Step 1: Tunnel 应该不通
echo ""
echo "── Step 1: Tunnel 应已关闭 ──"
if timeout 5 bash -c "echo > /dev/tcp/$SANGFOR_TEST_HOST/22" 2>/dev/null; then
  echo "⚠ TCP $SANGFOR_TEST_HOST:22 仍通（tunnel 可能没关）"
  echo "  检查 Sangfor 客户端是否真断开"
else
  echo "✓ TCP $SANGFOR_TEST_HOST:22 closed — tunnel gone"
fi
echo ""

# Step 2: 默认路由应仍走 eth0 家用
echo "── Step 2: 默认路由 ──"
DEFAULT_GW=$(ip route | grep '^default' | awk '{print $3}' | head -1)
DEFAULT_DEV=$(ip route | grep '^default' | awk '{print $5}' | head -1)
echo "  default via $DEFAULT_GW dev $DEFAULT_DEV"
if [ "$DEFAULT_DEV" = "eth0" ]; then
  echo "✓ 仍走家用 (eth0)"
else
  echo "⚠ 不是 eth0（可能 eth3 还在）"
fi
echo ""

# Step 3: 校园路由残留（kernel 会自动清，但需要看实际路径）
echo "── Step 3: 校园路由残留 ──"
ACTUAL_PATH_AFTER=$(ip route get "$SANGFOR_TEST_HOST" 2>/dev/null | head -1)
if echo "$ACTUAL_PATH_AFTER" | grep -q "eth3"; then
  echo "  $SANGFOR_TEST_HOST 仍走 eth3（tunnel 残留 / Sangfor 还在）"
else
  echo "✓ $SANGFOR_TEST_HOST 不再走 eth3（tunnel 真关）"
fi
echo ""

# Step 4: Clash 端点
echo "── Step 4: Clash 端点（7897）──"
if timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/7897" 2>/dev/null; then
  echo "✓ 7897 listening"
  if pgrep -f "Clash Verge" > /dev/null; then
    echo "  Clash Verge GUI 也在跑"
  else
    echo "  ⚠ 7897 listening 但 GUI 进程不在（可能后台 core 残留）"
    echo "  不阻塞正常用，但要 ChatGPT 浏览器代理可能要重启 Clash"
  fi
else
  echo "❌ 7897 closed"
  echo "  启动 Clash Verge（任务栏 → Clash 图标）"
fi
echo ""

# Step 5: 留底
echo "── Step 5: 留底 ──"
bash /home/cx/infra/network/network-status.sh "after-normal-on-$(date +%H%M)" > /dev/null 2>&1
echo "  Saved to ~/infra/network/snapshots/"
echo ""

echo "================================================"
echo "✅ 状态确认完成"
echo "================================================"
