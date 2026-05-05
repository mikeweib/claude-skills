#!/bin/bash
# 技术债扫描环境预检
# 用法: preflight-check.sh [project_dir]
# 输出: 语言检测 / 文件统计 / 环境状态
#
# 使用 --json 输出 JSON 格式便于程序化处理

set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
OUTPUT_FORMAT="${2:-text}"

echo "=== 技术债扫描环境预检 ==="
echo ""

# ===== 1. 项目目录验证 =====
echo "--- 项目目录 ---"
if [ ! -d "$PROJECT_DIR" ]; then
    echo "  [FAIL] 项目目录不存在: $PROJECT_DIR"
    exit 1
fi
echo "  [OK] 项目目录: $PROJECT_DIR"
echo ""

# ===== 2. 语言检测 =====
echo "--- 语言检测 ---"

# 定义语言扩展名映射
declare -A LANG_MAP
LANG_MAP=(
    ["c_cpp"]="*.c *.cc *.cpp *.cxx *.h *.hpp *.hh"
    ["java"]="*.java"
    ["python"]="*.py"
    ["js_ts"]="*.js *.jsx *.ts *.tsx *.mjs"
    ["go"]="*.go"
    ["rust"]="*.rs"
    ["swift"]="*.swift"
    ["csharp"]="*.cs"
    ["ruby"]="*.rb"
    ["shell"]="*.sh *.bash"
)

# 排除目录
EXCLUDE_DIRS="-not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/build/*' -not -path '*/dist/*' -not -path '*/.git/*' -not -path '*/target/*' -not -path '*/__pycache__/*'"

declare -A LANG_COUNTS
declare -A LANG_EXTENSIONS
total_files=0
detected_langs=""

for lang in "${!LANG_MAP[@]}"; do
    exts=(${LANG_MAP[$lang]})
    # 构建 find 的 -name 条件
    name_args=""
    for ext in "${exts[@]}"; do
        [ -n "$name_args" ] && name_args="$name_args -o -name '$ext'" || name_args="-name '$ext'"
    done

    # 用 eval 执行 find（安全，因为扩展名是硬编码的）
    cmd="find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( $name_args \) 2>/dev/null"
    count=$(eval "$cmd" | wc -l | tr -d ' ')

    if [ "$count" -gt 0 ]; then
        LANG_COUNTS[$lang]=$count
        total_files=$((total_files + count))
        LANG_EXTENSIONS[$lang]="${LANG_MAP[$lang]}"
        [ -n "$detected_langs" ] && detected_langs="$detected_langs, $lang" || detected_langs="$lang"
        echo "  [OK] $lang: $count 个文件"
    fi
done

if [ -z "$detected_langs" ]; then
    echo "  [FAIL] 未检测到任何支持的源码文件"
    exit 2
fi

echo "  总计: $total_files 个源码文件"
echo "  检测到语言: $detected_langs"
echo ""

# ===== 3. 文件统计 =====
echo "--- 文件统计 ---"

# 总行数
total_lines=0
for lang in "${!LANG_COUNTS[@]}"; do
    exts=(${LANG_MAP[$lang]})
    for ext in "${exts[@]}"; do
        lines=$(find "$PROJECT_DIR" -name "$ext" $EXCLUDE_DIRS -exec cat {} \; 2>/dev/null | wc -l | tr -d ' ')
        total_lines=$((total_lines + lines))
    done
done
echo "  总行数: $total_lines"

# 注释行数估算
comment_lines=$(find "$PROJECT_DIR" $EXCLUDE_DIRS -type f \( -name "*.c" -o -name "*.cc" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" -o -name "*.java" -o -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.go" -o -name "*.rs" \) -exec grep -c '^\s*\(//\|#\|/\*\|\*\)' {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}')

if [ "$comment_lines" -gt 0 ] 2>/dev/null; then
    echo "  注释行数 (估算): $comment_lines"
fi

echo ""

# ===== 4. 检查排除规则 =====
echo "--- 排除检查 ---"

excluded_dirs=""
for d in node_modules vendor build dist .git target __pycache__; do
    if [ -d "$PROJECT_DIR/$d" ]; then
        [ -n "$excluded_dirs" ] && excluded_dirs="$excluded_dirs, $d" || excluded_dirs="$d"
    fi
done
if [ -n "$excluded_dirs" ]; then
    echo "  [OK] 已排除: $excluded_dirs"
else
    echo "  [NOTE] 未发现标准排除目录"
fi
echo ""

# ===== 5. 汇总 =====
echo "=== 状态汇总 ==="

score=10
issues=""
max=10

# 检测到的语言数量加分
if [ "$total_files" -ge 100 ]; then
    echo "  规模: 大型项目 ($total_files 文件)"
elif [ "$total_files" -ge 20 ]; then
    echo "  规模: 中型项目 ($total_files 文件)"
else
    echo "  规模: 小型项目 ($total_files 文件)"
    # 小项目不减分，只是提示
fi

if [ "$total_lines" -gt 10000 ]; then
    echo "  代码量: $total_lines 行 — 技术债扫描将按密度计分"
fi

echo ""
echo "  预检得分: N/A (仅环境检查)"
echo "  就绪状态: 可执行技术债扫描"
echo "  下一步: 运行扫描脚本 (scan-marker-comments, scan-dead-code, scan-complexity, scan-deprecated-api)"
