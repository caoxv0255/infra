#!/bin/bash
# check-health.sh — read-only AI OS health check (WSL side)
# 退出码 = DOWN 服务数;0=全健康
# Ollama/Zotero app (Windows 侧) 只能 report,WSL 直连不到

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
DOWN=0
check(){ local n="$1" d="$2" c="$3"
  if eval "$c" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $n — $d"; return 0
  else echo -e "${RED}✗${NC} $n — $d"; return 1; fi; }

echo "=== AI OS Health Check ==="
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
check "tmux server"   "socket"         "[ -S /tmp/tmux-1000/default ]"                                  || DOWN=$((DOWN+1))
check "Docker"        "daemon ps"      "sg docker -c 'docker ps'"                                        || DOWN=$((DOWN+1))
check "LiteLLM"       ":4000 health"   "curl -sS --max-time 3 http://localhost:4000/health/liveliness"  || DOWN=$((DOWN+1))
check "Zotero API"    ":23119 items"   "curl -sS --max-time 3 http://127.0.0.1:23119/api/items"         || DOWN=$((DOWN+1))
echo ""
echo "tmux sessions:"; tmux ls 2>/dev/null | sed 's/^/  /' || echo "  (none)"
echo ""
[ $DOWN -eq 0 ] && echo -e "${GREEN}All WSL services healthy${NC}" \
                || echo -e "${YELLOW}$DOWN down — run 'recover' for tmux + LiteLLM,Windows 侧手动${NC}"
exit $DOWN
