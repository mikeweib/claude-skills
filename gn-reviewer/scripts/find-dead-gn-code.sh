#!/bin/bash
# 查找 BUILD.gn / .gni 中大段注释掉的死代码
# 用法: find-dead-gn-code.sh [directory] [--threshold 10]
# 输出: 超过阈值的连续注释块位置

set -euo pipefail

DIR="${1:-.}"
THRESHOLD=10

# 解析 --threshold
for arg in "$@"; do
    if [[ "$arg" == --threshold=* ]]; then
        THRESHOLD="${arg#--threshold=}"
    elif [[ "$arg" == --threshold ]] && [ -n "${2:-}" ]; then
        THRESHOLD="$2"
    fi
done

if [ ! -d "$DIR" ]; then
    echo "Error: directory not found: $DIR"
    exit 1
fi

echo "Scanning: $DIR (threshold: $THRESHOLD lines)"
echo ""

total_blocks=0
total_lines=0

while IFS= read -r gn_file; do
    # 统计连续注释行
    awk -v file="$gn_file" -v threshold="$THRESHOLD" '
    BEGIN { block_start = 0; block_lines = 0; in_block = 0 }
    /^[[:space:]]*#/ {
        if (!in_block) { block_start = NR; in_block = 1; block_lines = 0 }
        block_lines++
        next
    }
    {
        if (in_block) {
            if (block_lines >= threshold) {
                printf "%s:%d %d lines\n", file, block_start, block_lines
                total_blocks++
                total_lines += block_lines
            }
            in_block = 0
        }
    }
    END {
        if (in_block && block_lines >= threshold) {
            printf "%s:%d %d lines\n", file, block_start, block_lines
            total_blocks++
            total_lines += block_lines
        }
    }
    ' "$gn_file" 2>/dev/null
done < <(find "$DIR" -name 'BUILD.gn' -o -name '*.gni' | sort) > /tmp/gn_dead.txt

if [ ! -s /tmp/gn_dead.txt ]; then
    echo "No dead code blocks found (threshold: $THRESHOLD lines)."
    rm -f /tmp/gn_dead.txt
    exit 0
fi

echo "=== 注释掉的代码块 (>=$THRESHOLD 行) ==="
cat /tmp/gn_dead.txt
echo ""

# 附加检查: 注释掉的 target 定义
echo "=== 注释掉的 target 定义 ==="
grep -rn '^[[:space:]]*#.*(source_set\|#.*static_library\|#.*executable\|#.*group\|#.*rtc_source_set\|#.*rtc_static_library)\(' \
    "$DIR" --include='BUILD.gn' --include='*.gni' 2>/dev/null \
    | head -20 || echo "  (none)"
echo ""

# 附加检查: 注释掉的 deps
echo "=== 注释掉的 deps ==="
grep -rn '^[[:space:]]*#.*deps[[:space:]]*' "$DIR" --include='BUILD.gn' --include='*.gni' 2>/dev/null \
    | head -20 || echo "  (none)"
echo ""

block_count=$(wc -l < /tmp/gn_dead.txt 2>/dev/null || echo 0)
echo "=== 汇总 ==="
echo "  死代码块: $block_count"

rm -f /tmp/gn_dead.txt
