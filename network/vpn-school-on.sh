#!/bin/bash
# vpn-school-on.sh — Day 1 改写 v4：能力检测 + 验证模式（不加路由）
#
# 关键：Sangfor 已经是 split tunnel 模式，自动推 219.224.x.x 路由
#       手动 add 是重复操作，可能产生 duplicate route / metric conflict
#
# 改写后只做：
#   1. 检查 Sangfor tunnel 真工作（TCP 219.224.3.96:22）
#   2. 检查 UIBE 路由（应该已自动有）
#   3. 测 SSH 认证（用 SSH key）
#   4. 输出状态
#
# 不动任何路由

set -e
SANGFOR_TEST_HOST="219.224.3.96"  # 组员机器

echo "================================================"
echo "Sangfor 校园 VPN 状态检查 — $(date '+%H:%M:%S')"
echo "================================================"

# Step 1: Tunnel capability check
echo ""
echo "── Step 1: Tunnel capability check ──"
if timeout 5 bash -c "echo > /dev/tcp/$SANGFOR_TEST_HOST/22" 2>/dev/null; then
  echo "✓ TCP $SANGFOR_TEST_HOST:22 OK — tunnel alive"
  TUNNEL_OK=true
else
  echo "❌ TCP $SANGFOR_TEST_HOST:22 closed — tunnel NOT working"
  echo ""
  echo "请检查："
  echo "  1. 任务栏 → Sangfor 客户端 → 状态显示 '已连接'？"
  echo "  2. 虚拟 IP 有数字？"
  echo "  3. 流量 > 0？"
  echo "  4. 如有，重连 Sangfor 后重跑本脚本"
  exit 1
fi
echo ""

# Step 2: UIBE 路由检查
echo "── Step 2: UIBE 路由（应该已自动有）──"
# 用 ip route get 看真实路径（不用 grep 因为 1.0.0.0/8 也覆盖 219.x）
ACTUAL_PATH=$(ip route get "$SANGFOR_TEST_HOST" 2>/dev/null | head -1)
if [ -n "$ACTUAL_PATH" ]; then
  echo "✓ $SANGFOR_TEST_HOST 路由: $ACTUAL_PATH"
  if echo "$ACTUAL_PATH" | grep -q "eth3"; then
    echo "  (走 Sangfor tunnel — OK)"
  else
    echo "  (走 $DEFAULT_DEV — 警告：可能没走 Sangfor)"
  fi
else
  echo "❌ 无法获取路由"
fi
echo ""

# Step 3: SSH 认证
echo "── Step 3: SSH 认证（用 SSH key，BatchMode）──"
if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes xh@$SANGFOR_TEST_HOST whoami 2>&1 | head -3; then
  SSH_OK=true
else
  SSH_OK=false
fi
echo ""

# Step 4: 输出最终状态
echo "================================================"
echo "总结"
echo "================================================"
# Step 2 输出 ACTUAL_PATH，再用它判断
UIBE_OK=false
if echo "$ACTUAL_PATH" | grep -q "eth3"; then
  UIBE_OK=true
fi
echo "  Tunnel:    $([ "$TUNNEL_OK" = "true" ] && echo "✓ OK" || echo "❌ FAIL")"
echo "  UIBE:      $([ "$UIBE_OK" = "true" ] && echo "✓ OK" || echo "❌ FAIL")"
echo "  SSH auth:  $([ "$SSH_OK" = "true" ] && echo "✓ OK" || echo "⚠ pending — 跑 ssh -vvv 调试")"
echo "================================================"

if [ "$TUNNEL_OK" = "true" ] && [ "$UIBE_OK" = "true" ]; then
  echo ""
  echo "✅ 校园 VPN 状态正常，可以拉代码 / SSH"
  echo "  - bash ~/pull_teammates.sh"
  echo "  - ssh xh@$SANGFOR_TEST_HOST"
  exit 0
else
  echo ""
  echo "❌ 有问题需要修，先解决再继续"
  exit 1
fi
