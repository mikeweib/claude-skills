#!/bin/bash
# 复杂度分析
# 用法: scan-complexity.sh [project_dir]
# 输出: 按子类型分组的 file:line 格式结果 + 扣分汇总
#
# 检测: 超大文件(>800行) / 长函数(>50行) / 深层嵌套(>=4) / 过多参数(>=5)

set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: 目录不存在: $PROJECT_DIR"
    exit 1
fi

EXCLUDE_DIRS="-not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/build/*' -not -path '*/dist/*' -not -path '*/.git/*' -not -path '*/target/*' -not -path '*/__pycache__/*'"

C_EXTS="-name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' -o -name '*.h' -o -name '*.hpp' -o -name '*.hh' -o -name '*.java' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' -o -name '*.mjs' -o -name '*.go' -o -name '*.rs' -o -name '*.swift' -o -name '*.cs'"

PY_EXTS="-name '*.py'"

echo "=== 复杂度分析 ==="
echo ""

# ===== 1. 超大文件 (>800 行) =====
echo "--- 超大文件 (>800 行) -2分/文件 ---"
echo ""

large_file_count=0

while IFS= read -r file; do
    [ -z "$file" ] && continue
    # 排除生成文件
    case "$file" in
        *generated*|*.pb.*|*.g.*|*_generated.*) continue ;;
    esac
    lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
    if [ "$lines" -gt 800 ] 2>/dev/null; then
        echo "  $file:$lines 行"
        large_file_count=$((large_file_count + 1))
    fi
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS -o $PY_EXTS \) -type f 2>/dev/null" | head -500)

echo "  超大文件: $large_file_count"
echo ""

# ===== 2. 长函数 (>50 行) =====
echo "--- 长函数 (>50 行) -1分/函数 ---"
echo ""

long_func_count=0

# C-family: 用 awk 近似检测函数长度（通过 { } 配对）
while IFS= read -r file; do
    [ -z "$file" ] && continue
    case "$file" in
        *generated*|*.pb.*|*.g.*|*_generated.*) continue ;;
    esac
    # 找函数定义行号，然后近似计算到闭合大括号的行数
    awk '
    /^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_:<>*&[:space:]]+[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([^)]*\)[[:space:]]*\{/ {
        func_start = NR
        depth = 1
        next
    }
    depth > 0 {
        # 简单 brace 计数
        n_open = gsub(/\{/, "&")
        n_close = gsub(/\}/, "&")
        depth += n_open - n_close
        if (depth == 0) {
            func_len = NR - func_start
            if (func_len > 50) {
                printf "  %s:%d: 函数约 %d 行 (定义行 %d)\n", FILENAME, func_start, func_len, func_start
            }
        }
    }
    ' "$file"
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -type f 2>/dev/null" | head -300)

# Python: def 函数检测
while IFS= read -r file; do
    [ -z "$file" ] && continue
    case "$file" in
        *generated*|*.pb.*|*.g.*|*_generated.*) continue ;;
    esac
    awk '
    /^[[:space:]]*def [a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(/ {
        if (func_start > 0) {
            func_len = NR - func_start
            if (func_len > 50) {
                printf "  %s:%d: 函数约 %d 行 (定义行 %d)\n", FILENAME, func_start, func_len, func_start
            }
        }
        func_start = NR
        func_indent = match($0, /[^[:space:]]/) - 1
        next
    }
    func_start > 0 {
        cur_indent = match($0, /[^[:space:]]/)
        if (cur_indent > 0 && cur_indent - 1 <= func_indent && $0 !~ /^[[:space:]]*$/) {
            func_len = NR - func_start
            if (func_len > 50) {
                printf "  %s:%d: 函数约 %d 行 (定义行 %d)\n", FILENAME, func_start, func_len, func_start
            }
            func_start = 0
        }
    }
    END {
        if (func_start > 0) {
            func_len = NR - func_start
            if (func_len > 50) {
                printf "  %s:%d: 函数约 %d 行 (定义行 %d)\n", FILENAME, func_start, func_len, func_start
            }
        }
    }
    ' "$file"
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $PY_EXTS \) -type f 2>/dev/null" | head -200)

# 用简单方式统计实际数量（避免 awk 复杂度带来的重复计数）
long_func_count=$(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS -o $PY_EXTS \) -type f 2>/dev/null" | head -300 | while IFS= read -r f; do
    awk '/^[[:space:]]*(def |[a-zA-Z_][a-zA-Z0-9_:<>*&[:space:]]+[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\([^)]*\)[[:space:]]*\{/ {s=NR; d=1; next}
         d>0 {o=gsub(/\{/,"&"); c=gsub(/\}/,"&"); d+=o-c; if(d==0&&NR-s>50){n++}}
         END{print n+0}' "$f" 2>/dev/null
done | awk '{s+=$1} END {print s+0}' || echo "0")

echo "  长函数: $long_func_count (估算)"
echo ""

# ===== 3. 深层嵌套 (>=4 层) =====
echo "--- 深层嵌套 (>=4 层) -2分/处 ---"
echo ""

deep_nest_count=0

# 简单检测：连续 4 层缩进大括号
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    deep_nest_count=$((deep_nest_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -type f -exec grep -HIn '^[[:space:]]\{16,}\(if\|for\|while\|switch\)' {} \; 2>/dev/null | head -30" || true)

# Python: 16+ 空格缩进 (4 层 * 4 spaces)
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    deep_nest_count=$((deep_nest_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $PY_EXTS \) -type f -exec grep -HIn '^[[:space:]]\{16,}\(if\|for\|while\|with\|try\)' {} \; 2>/dev/null | head -20" || true)

echo "  深层嵌套: $deep_nest_count (前30条)"
echo ""

# ===== 4. 过多参数 (>=5) =====
echo "--- 过多参数 (>=5 个) -1分/函数 ---"
echo ""

many_params_count=0

# C-family: 函数签名中 >=5 个逗号分隔的参数
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    many_params_count=$((many_params_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $C_EXTS \) -type f -exec grep -HIn '([^)]*,[^)]*,[^)]*,[^)]*,[^)]*)' {} \; 2>/dev/null | grep -v '#include\|#define\|import\|using\|return ' | head -30" || true)

# Python: def 中 >=5 个参数
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    many_params_count=$((many_params_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $PY_EXTS \) -type f -exec grep -HIn 'def [a-zA-Z_][a-zA-Z0-9_]*([^)]*,[^)]*,[^)]*,[^)]*,[^)]*)' {} \; 2>/dev/null | head -20" || true)

echo "  过多参数: $many_params_count (前30条)"
echo ""

# ===== 扣分计算 =====
large_penalty=0
[ "$large_file_count" -gt 0 ] && large_penalty=$((large_file_count * 2 > 8 ? 8 : large_file_count * 2))

func_penalty=0
[ "$long_func_count" -gt 0 ] && func_penalty=$((long_func_count * 1 > 8 ? 8 : long_func_count * 1))

nest_penalty=0
[ "$deep_nest_count" -gt 0 ] && nest_penalty=$((deep_nest_count * 2 > 5 ? 5 : deep_nest_count * 2))

params_penalty=0
[ "$many_params_count" -gt 0 ] && params_penalty=$((many_params_count * 1 > 4 ? 4 : many_params_count * 1))

total_penalty=$((large_penalty + func_penalty + nest_penalty + params_penalty))
score=$((25 - total_penalty > 0 ? 25 - total_penalty : 0))

echo "=== 扣分汇总 ==="
echo "  超大文件 (>800行): $large_file_count 个 → -$large_penalty"
echo "  长函数 (>50行):   $long_func_count 个 → -$func_penalty"
echo "  深层嵌套 (>=4):   $deep_nest_count 处 → -$nest_penalty"
echo "  过多参数 (>=5):   $many_params_count 个 → -$params_penalty"
echo "  ----------------------------------------"
echo "  类别得分: $score/25"
