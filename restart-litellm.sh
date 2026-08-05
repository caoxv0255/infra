#!/bin/bash
# restart-litellm.sh —— 重启 LiteLLM 容器让 config 改动生效
# 用法：bash ~/infra/restart-litellm.sh

set -e
cd "$(dirname "$0")"

echo "=== 当前 alias ==="
curl -s http://localhost:4000/v1/models 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for m in d.get('data', []):
    print(' -', m['id'])
" 2>/dev/null || echo "(服务未响应)"

echo ""
echo "=== 重启容器 ==="
sg docker -c 'docker compose restart litellm'

echo ""
echo "=== 等 15 秒 ==="
sleep 15

echo "=== 重启后 alias ==="
curl -s http://localhost:4000/v1/models 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for m in d.get('data', []):
    print(' -', m['id'])
" 2>/dev/null || echo "(服务未响应)"
