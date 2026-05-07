#!/bin/bash
# 死代码检测
# 用法: scan-dead-code.sh [project_dir] [--threshold N]
# 输出: 按子类型分组的 file:line 格式结果 + 扣分汇总
#
# 检测: 注释代码块 / 空 catch 块 / 死条件分支 / return 后不可达代码

set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
THRESHOLD=10  # 注释代码块最小行数

# 解析可选参数
shift 2>/dev/null || true
for arg in "$@"; do
    case "$arg" in
        --threshold) THRESHOLD="${2:-10}"; shift 2 2>/dev/null || true ;;
    esac
done

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: 目录不存在: $PROJECT_DIR"
    exit 1
fi

EXCLUDE_DIRS="-not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/third_party/*' -not -path '*/build/*' -not -path '*/dist/*' -not -path '*/.git/*' -not -path '*/target/*' -not -path '*/__pycache__/*'"

C_EXTS="-name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' -o -name '*.h' -o -name '*.hpp' -o -name '*.hh' -o -name '*.java' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' -o -name '*.mjs' -o -name '*.go' -o -name '*.rs' -o -name '*.swift' -o -name '*.cs'"

PY_EXTS="-name '*.py'"

ALL_EXTS="$C_EXTS -o $PY_EXTS"

echo "=== 死代码检测 ==="
echo ""

# ===== 1. 注释代码块 (>THRESHOLD 行) =====
echo "--- 注释代码块 (>=$THRESHOLD 行连续注释) -3分/块 ---"
echo ""

comment_block_count=0
total_comment_lines=0

# C-family: 连续 // 注释行
while IFS= read -r file; do
    [ -z "$file" ] && continue
    # 用 awk 找连续 >= THRESHOLD 行的注释块
    awk -v threshold="$THRESHOLD" '
    BEGIN { start=0; count=0 }
    /^[[:space:]]*\/\// {
        if (count == 0) start = NR
        count++
        next
    }
    {
        if (count >= threshold) {
            printf "  %s:%d: 注释代码块 (%d 行连续注释)\n", FILENAME, start, count
        }
        count = 0
    }
    END {
        if (count >= threshold) {
            printf "  %s:%d: 注释代码块 (%d 行连续注释)\n", FILENAME, start, count
        }
    }
    ' "$file"
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -type f 2>/dev/null" | head -500)

# Python: 连续 # 注释行
while IFS= read -r file; do
    [ -z "$file" ] && continue
    awk -v threshold="$THRESHOLD" '
    BEGIN { start=0; count=0 }
    /^[[:space:]]*#[^!]/ {
        if (count == 0) start = NR
        count++
        next
    }
    {
        if (count >= threshold) {
            printf "  %s:%d: 注释代码块 (%d 行连续注释)\n", FILENAME, start, count
        }
        count = 0
    }
    END {
        if (count >= threshold) {
            printf "  %s:%d: 注释代码块 (%d 行连续注释)\n", FILENAME, start, count
        }
    }
    ' "$file"
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $PY_EXTS \) -type f 2>/dev/null" | head -200)

# 用 grep 统计实际数量
comment_block_count=$(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $ALL_EXTS \) -type f -exec grep -c '^[[:space:]]*\(//\|#\)' {} \; 2>/dev/null" | awk -v t="$THRESHOLD" '$1 >= t {c++} END {print c+0}')

echo "  注释代码块 (估): $comment_block_count"
echo ""

# ===== 2. 空 catch 块 =====
echo "--- 空 catch 块 -2分/条 ---"
echo ""

empty_catch_count=0

# C-family: empty catch {}
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    empty_catch_count=$((empty_catch_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -type f -exec grep -HIn 'catch\s*([^)]*)\s*{\s*}' {} \; 2>/dev/null" || true)

# C-family: catch with only whitespace/comments
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    empty_catch_count=$((empty_catch_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( -name '*.java' -o -name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx' \) -type f -exec grep -HIn 'catch\s*([^)]*)\s*{\s*//.*}' {} \; 2>/dev/null" || true)

# Python: except: pass / except: (blank line)
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    empty_catch_count=$((empty_catch_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $PY_EXTS \) -type f -exec grep -HIn 'except[^:]*:\s*$' {} \; 2>/dev/null" || true)

echo "  空 catch 块: $empty_catch_count"
echo ""

# ===== 3. 死条件分支 =====
echo "--- 死条件分支 (if(false)/if(0)) -3分/条 ---"
echo ""

dead_cond_count=0

# if (false) or if (0)
while IFS= read -r line; do
    [ -z "$line" ] && continue
    # 排除模板特化 (C++ template<...> 上下文)
    echo "  $line"
    dead_cond_count=$((dead_cond_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -type f -exec grep -HIn 'if\s*(\s*\(false\|0\|FALSE\|nullptr\|None\|nil\)\s*)' {} \; 2>/dev/null" || true)

while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    dead_cond_count=$((dead_cond_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $PY_EXTS \) -type f -exec grep -HIn 'if\s*\(*\)\s*False' {} \; 2>/dev/null" || true)

echo "  死条件分支: $dead_cond_count"
echo ""

# ===== 4. return 后不可达代码 =====
echo "--- return 后不可达代码 -1分/条 ---"
echo ""

unreachable_count=0

# 简化检测: return; 后紧跟的非空行
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    unreachable_count=$((unreachable_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -type f -exec awk '/return[;\s]*$/ {nr=NR; next} NR==nr+1 && /^[[:space:]]+[a-zA-Z]/ {printf \"%s:%d: unreachable after return\n\", FILENAME, NR}' {} \; 2>/dev/null" || true)

echo "  return 后不可达代码: $unreachable_count"
echo ""

# ===== 扣分计算 =====
comment_penalty=0
[ "$comment_block_count" -gt 0 ] && comment_penalty=$((comment_block_count * 3 > 9 ? 9 : comment_block_count * 3))

catch_penalty=0
[ "$empty_catch_count" -gt 0 ] && catch_penalty=$((empty_catch_count * 2 > 8 ? 8 : empty_catch_count * 2))

cond_penalty=0
[ "$dead_cond_count" -gt 0 ] && cond_penalty=$((dead_cond_count * 3 > 6 ? 6 : dead_cond_count * 3))

unreachable_penalty=0
[ "$unreachable_count" -gt 0 ] && unreachable_penalty=$((unreachable_count * 1 > 2 ? 2 : unreachable_count * 1))

total_penalty=$((comment_penalty + catch_penalty + cond_penalty + unreachable_penalty))
score=$((20 - total_penalty > 0 ? 20 - total_penalty : 0))

echo "=== 扣分汇总 ==="
echo "  注释代码块:       $comment_block_count 块 → -$comment_penalty"
echo "  空 catch 块:      $empty_catch_count 条 → -$catch_penalty"
echo "  死条件分支:       $dead_cond_count 条 → -$cond_penalty"
echo "  return后不可达:   $unreachable_count 条 → -$unreachable_penalty"
echo "  ----------------------------------------"
echo "  类别得分: $score/20"
