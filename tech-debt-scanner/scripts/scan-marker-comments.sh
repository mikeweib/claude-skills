#!/bin/bash
# 标记注释扫描
# 用法: scan-marker-comments.sh [project_dir]
# 输出: 按严重程度分组的 file:line 格式结果 + 扣分汇总
#
# 扫描 TODO/FIXME/HACK/XXX/BUG/OPTIMIZE/WORKAROUND/TEMP/KLUDGE 标记

set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: 目录不存在: $PROJECT_DIR"
    exit 1
fi

# 排除目录
EXCLUDE_DIRS="-not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/build/*' -not -path '*/dist/*' -not -path '*/.git/*' -not -path '*/target/*' -not -path '*/__pycache__/*' -not -path '*/.claude/*'"

# C-family 扩展名
C_EXTS="-name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' -o -name '*.h' -o -name '*.hpp' -o -name '*.hh' -o -name '*.java' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' -o -name '*.mjs' -o -name '*.go' -o -name '*.rs' -o -name '*.swift' -o -name '*.cs'"

# Python/Ruby/Shell
SCRIPT_EXTS="-name '*.py' -o -name '*.rb' -o -name '*.sh' -o -name '*.bash'"

echo "=== 标记注释扫描 ==="
echo ""

# 统计源码文件
file_count=$(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS -o $SCRIPT_EXTS \) 2>/dev/null" | wc -l | tr -d ' ')
echo "扫描范围: $file_count 个源码文件"
echo ""

# ===== 严重: FIXME, HACK =====
echo "--- 严重 (FIXME / HACK) -3分/条 ---"
echo ""

fixme_count=0
hack_count=0

# C-family: FIXME in comments
while IFS= read -r line; do
    [ -n "$line" ] && echo "  $line" && fixme_count=$((fixme_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -exec grep -HIn '//.*\(FIXME\|fixme\)' {} \; 2>/dev/null" | grep -v '://' | grep -v 'SPDX\|License\|Copyright' || true)

# Script languages: FIXME in comments
while IFS= read -r line; do
    [ -n "$line" ] && echo "  $line" && fixme_count=$((fixme_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $SCRIPT_EXTS \) -exec grep -HIn '#.*\(FIXME\|fixme\)' {} \; 2>/dev/null" | grep -v '://' | grep -v 'SPDX\|License\|Copyright' || true)

# HACK
while IFS= read -r line; do
    [ -n "$line" ] && echo "  $line" && hack_count=$((hack_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -exec grep -HIn '//.*\(HACK\|hack\)' {} \; 2>/dev/null" | grep -v '://' | grep -v 'SPDX\|License\|Copyright' || true)

while IFS= read -r line; do
    [ -n "$line" ] && echo "  $line" && hack_count=$((hack_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $SCRIPT_EXTS \) -exec grep -HIn '#.*\(HACK\|hack\)' {} \; 2>/dev/null" | grep -v '://' | grep -v 'SPDX\|License\|Copyright' || true)

echo "  严重标记: FIXME=$fixme_count, HACK=$hack_count"
echo ""

# ===== 显著: XXX, TEMP, KLUDGE, BUG, OPTIMIZE, WORKAROUND =====
echo "--- 显著 (XXX / TEMP / KLUDGE / BUG / OPTIMIZE / WORKAROUND) -2分/条 ---"
echo ""

sig_count=0

for marker in XXX TEMP KLUDGE BUG OPTIMIZE WORKAROUND; do
    marker_upper=$(echo "$marker" | tr '[:lower:]' '[:upper:]')
    while IFS= read -r line; do
        [ -n "$line" ] && echo "  $line" && sig_count=$((sig_count + 1))
    done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -exec grep -HIn \"//.*$marker_upper\" {} \; 2>/dev/null" | grep -v '://' | grep -v 'SPDX\|License\|Copyright' || true)

    while IFS= read -r line; do
        [ -n "$line" ] && echo "  $line" && sig_count=$((sig_count + 1))
    done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $SCRIPT_EXTS \) -exec grep -HIn \"#.*$marker_upper\" {} \; 2>/dev/null" | grep -v '://' | grep -v 'SPDX\|License\|Copyright' || true)
done

echo "  显著标记: $sig_count 条"
echo ""

# ===== 中等: TODO =====
echo "--- 中等 (TODO) -1分/条 ---"
echo ""

todo_count=0

while IFS= read -r line; do
    [ -n "$line" ] && echo "  $line" && todo_count=$((todo_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -exec grep -HIn '//.*\(TODO\|todo\)' {} \; 2>/dev/null" | grep -v '://' | grep -v 'SPDX\|License\|Copyright' || true)

while IFS= read -r line; do
    [ -n "$line" ] && echo "  $line" && todo_count=$((todo_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $SCRIPT_EXTS \) -exec grep -HIn '#.*\(TODO\|todo\)' {} \; 2>/dev/null" | grep -v '://' | grep -v 'SPDX\|License\|Copyright' || true)

echo "  TODO 标记: $todo_count 条"
echo ""

# ===== 扣分计算 =====
critical_count=$((fixme_count + hack_count))
critical_penalty=0
[ "$critical_count" -gt 0 ] && critical_penalty=$(echo "if ($critical_count * 3 > 9) 9 else $critical_count * 3" | bc 2>/dev/null || echo $((critical_count * 3 > 9 ? 9 : critical_count * 3)))

sig_penalty=0
[ "$sig_count" -gt 0 ] && sig_penalty=$(echo "if ($sig_count * 2 > 8) 8 else $sig_count * 2" | bc 2>/dev/null || echo $((sig_count * 2 > 8 ? 8 : sig_count * 2)))

todo_penalty=0
[ "$todo_count" -gt 0 ] && todo_penalty=$(echo "if ($todo_count > 8) 8 else $todo_count" | bc 2>/dev/null || echo $((todo_count > 8 ? 8 : todo_count)))

total_penalty=$((critical_penalty + sig_penalty + todo_penalty))
score=$((25 - total_penalty > 0 ? 25 - total_penalty : 0))

echo "=== 扣分汇总 ==="
echo "  严重 (FIXME/HACK): $critical_count 条 → -$critical_penalty"
echo "  显著 (XXX/TEMP等): $sig_count 条 → -$sig_penalty"
echo "  中等 (TODO):       $todo_count 条 → -$todo_penalty"
echo "  -------------------------------"
echo "  类别得分: $score/25"
