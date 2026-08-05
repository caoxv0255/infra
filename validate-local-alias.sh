#!/bin/bash
# validate-local-alias.sh —— 验证 LiteLLM 的 "local" alias 真能调到 Ollama
# 用法：bash ~/infra/validate-local-alias.sh
#
# 注意：用 model=local 时会调本地 Ollama (11434)
# 没有 Ollama 或没装 qwen3:14b 会自然失败 — 不影响 LiteLLM 本身

set -e
echo "=== 1) LiteLLM 别 alias 列表 ==="
curl -s http://localhost:4000/v1/models 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for m in d.get('data', []):
    print('  -', m['id'])
" 2>/dev/null || { echo "❌ LiteLLM 没响应，请先跑 restart-litellm.sh"; exit 1; }

echo ""
echo "=== 2) 检查 Windows Ollama 是否在 11434 ==="
# 直接调 Windows host loopback（WSL 内可通过 localhost 通到 host）
curl -s -m 5 http://localhost:11434/api/version 2>&1 | head -3
echo ""

echo "=== 3) 用 LiteLLM 'local' alias 跑一个最小 chat ==="
curl -s -m 60 http://localhost:4000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local",
    "messages": [{"role":"user","content":"reply with just: ollama-ok"}],
    "max_tokens": 30
  }' | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('choices'):
    print('REPLY:', repr(d['choices'][0]['message']['content']))
    print('MODEL:', d.get('model'))
    print('USAGE:', d.get('usage'))
else:
    print('ERROR:', d)
"

echo ""
echo "=== 4) Litellm 日志（看是 forward 到 Ollama 还是 fail） ==="
sg docker -c 'docker logs --tail=15 hermes-litellm' 2>&1 | grep -E "(ollama|local|error|Error)" | head -10
