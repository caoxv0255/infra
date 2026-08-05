#!/bin/bash
# fix-wsl-path.sh —— WSL PATH 去重 + 死路径清理
# 默认 dry-run：只打印要做什么；加 --apply 才真改 ~/.bashrc
# 用法：
#   bash fix-wsl-path.sh                # 等价 --dry-run
#   bash fix-wsl-path.sh --dry-run      # 打印报告
#   bash fix-wsl-path.sh --apply        # 改 ~/.bashrc

set -e
APPLY=false
if [ "$1" = "--apply" ]; then APPLY=true; fi

BASHRC="$HOME/.bashrc"
TMPPATH="/tmp/cleaned-path.txt"

echo "=== 当前 PATH 状态 ==="
TOTAL=$(echo "$PATH" | tr ':' '\n' | wc -l)
UNIQ=$(echo "$PATH" | tr ':' '\n' | sort -u | wc -l)
echo "总: $TOTAL 个 dir, 去重后 $UNIQ 个"
echo ""

echo "=== 1) 去重 + 移除死路径 ==="
# 用 Python 真正做这事（bash 处理路径分隔太脆弱）
python3 - "$PATH" > "$TMPPATH" <<'EOF'
import os, sys
from collections import OrderedDict
raw = sys.argv[1]
seen = OrderedDict()
dead_count = 0
duplicate_count = 0
for d in raw.split(':'):
    if not d or d in seen:
        if d in seen:
            duplicate_count += 1
        else:
            duplicate_count += 1  # empty string duplicate
        continue
    seen[d] = True
    if not os.path.isdir(d):
        dead_count += 1
        print(f"  DROP (dead) {d}")
    else:
        print(f"  KEEP        {d}")
print(f"\n# {duplicate_count} duplicates skipped, {dead_count} dead paths removed")
print(f"# {len(seen)} directories remain")
EOF

CLEANED=$(cat "$TMPPATH" | grep "^  KEEP " | awk '{print $2}')
echo ""
echo "=== 2) 编辑 ~/.bashrc（PATH 行） ==="

if $APPLY; then
    # 备份
    cp "$BASHRC" "$BASHRC.bak.$(date +%Y%m%d-%H%M%S)"
    echo "已备份 $BASHRC"

    # 替换 PATH 行（找包含 "PATH=" 和 "$PATH" 的 export 行）
    if grep -qE '^export PATH=' "$BASHRC"; then
        # 取 KEEP 行的真实路径（用 sed 提"  KEEP" 后面的所有内容）
        CLEANED=$(cat "$TMPPATH" | sed -n 's/^  KEEP[[:space:]]*//p')
        CLEANED_STR=$(echo "$CLEANED" | tr '\n' ':' | sed 's/:$//')

        # 删除旧 export PATH 行
        sed -i.bak2 '/^export PATH=/d' "$BASHRC"
        # 在文件末尾追加新的（用一行 export）
        echo "" >> "$BASHRC"
        echo "# Auto-cleaned PATH by fix-wsl-path.sh on $(date)" >> "$BASHRC"
        echo "export PATH=\"$CLEANED_STR:\$PATH\"" >> "$BASHRC"
        echo "✅ 已更新 ~/.bashrc（一份新 export PATH，旧的全部删除）"
        echo "   请 source 一次: source ~/.bashrc"
    else
        echo "⚠️  ~/.bashrc 没有 export PATH= 行；未改动"
    fi
else
    echo "(dry-run) 打印计划，未改任何文件"
    echo ""
    echo "如果看着 OK，重跑: bash $0 --apply"
fi
