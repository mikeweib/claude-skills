#!/bin/bash
# 废弃 API 扫描
# 用法: scan-deprecated-api.sh [project_dir]
# 输出: 按语言分组的 file:line 格式结果 + 扣分汇总
#
# 扫描: @deprecated 注解 + 各语言的已知废弃 API 模式

set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: 目录不存在: $PROJECT_DIR"
    exit 1
fi

EXCLUDE_DIRS="-not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/build/*' -not -path '*/dist/*' -not -path '*/.git/*' -not -path '*/target/*' -not -path '*/__pycache__/*'"

echo "=== 废弃 API 扫描 ==="
echo ""

# ===== 1. 注解/属性标记的废弃 =====
echo "--- 注解标记的废弃 (via @deprecated / #[deprecated]) -3分/条 ---"
echo ""

annotation_count=0

# JSDoc @deprecated
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    annotation_count=$((annotation_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( -name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx' \) -type f -exec grep -HIn '@deprecated' {} \; 2>/dev/null" || true)

# Java @Deprecated
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    annotation_count=$((annotation_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS -name '*.java' -type f -exec grep -HIn '@Deprecated' {} \; 2>/dev/null" || true)

# Rust #[deprecated]
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    annotation_count=$((annotation_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS -name '*.rs' -type f -exec grep -HIn '#\[deprecated' {} \; 2>/dev/null" || true)

# Swift @available(*, deprecated)
while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  $line"
    annotation_count=$((annotation_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS -name '*.swift' -type f -exec grep -HIn '@available.*deprecated' {} \; 2>/dev/null" || true)

echo "  注解标记: $annotation_count"
echo ""

# ===== 2. 已知废弃 API 模式 =====
echo "--- 已知废弃 API 使用 -2分/条 ---"
echo ""

api_count=0

# --- C/C++ unsafe ---
echo "  [C/C++] 不安全函数:"
echo ""

for func in gets sprintf strcpy strcat tmpnam mktemp; do
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # 排除在注释中的
        echo "    $line"
        api_count=$((api_count + 1))
    done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.cxx' -o -name '*.h' -o -name '*.hpp' \) -type f -exec grep -HIn \"\<${func}\s*(\" {} \; 2>/dev/null | grep -v '^\s*//' | grep -v '^\s*#' || true" | head -5)
done

echo ""

# --- Python deprecated ---
echo "  [Python] 废弃模块/函数:"
echo ""

for pattern in 'import distutils' 'from distutils' 'import imp$' 'from imp ' 'start_new_thread' 'getargspec' '\.message'; do
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "    $line"
        api_count=$((api_count + 1))
    done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS -name '*.py' -type f -exec grep -HIn \"$pattern\" {} \; 2>/dev/null | grep -v '^\s*#' | head -5" || true)
done

echo ""

# --- JS/TS deprecated ---
echo "  [JS/TS] 废弃 API:"
echo ""

for pattern in 'document\.write(' 'arguments\.callee' '\.__proto__' 'unescape(' 'escape(' 'var '; do
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "    $line"
        api_count=$((api_count + 1))
    done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS \( -name '*.js' -o -name '*.ts' -o -name '*.jsx' -o -name '*.tsx' -o -name '*.mjs' \) -type f -exec grep -HIn \"$pattern\" {} \; 2>/dev/null | grep -v '^\s*//' | grep -v node_modules | head -5" || true)
done

echo ""

# --- Java deprecated ---
echo "  [Java] 废弃 API:"
echo ""

for pattern in 'new Date()' 'Thread\.stop(' 'Thread\.suspend(' 'Thread\.resume(' 'finalize()' 'new Vector<' 'new Hashtable<' 'Enumeration'; do
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "    $line"
        api_count=$((api_count + 1))
    done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS -name '*.java' -type f -exec grep -HIn \"$pattern\" {} \; 2>/dev/null | grep -v '^\s*//' | head -5" || true)
done

echo ""

# --- Go deprecated ---
echo "  [Go] 废弃 API (ioutil -> io/os):"
echo ""

for pattern in 'ioutil\.ReadAll' 'ioutil\.ReadFile' 'ioutil\.WriteFile' 'ioutil\.TempDir' 'ioutil\.NopCloser' 'ioutil\.Discard'; do
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "    $line"
        api_count=$((api_count + 1))
    done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS -name '*.go' -type f -exec grep -HIn \"$pattern\" {} \; 2>/dev/null | grep -v '^\s*//' | head -5" || true)
done

echo ""

# --- Rust deprecated ---
echo "  [Rust] 废弃 API:"
echo ""

while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "    $line"
    api_count=$((api_count + 1))
done < <(eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS -name '*.rs' -type f -exec grep -HIn 'std::mem::uninitialized\|std::env::home_dir' {} \; 2>/dev/null | grep -v '^\s*//' | head -5" || true)

echo "  已知废弃 API: $api_count"
echo ""

# ===== 扣分计算 =====
ann_penalty=0
[ "$annotation_count" -gt 0 ] && ann_penalty=$((annotation_count * 3 > 12 ? 12 : annotation_count * 3))

api_penalty=0
[ "$api_count" -gt 0 ] && api_penalty=$((api_count * 2 > 13 ? 13 : api_count * 2))

total_penalty=$((ann_penalty + api_penalty))
score=$((20 - total_penalty > 0 ? 20 - total_penalty : 0))

echo "=== 扣分汇总 ==="
echo "  注解标记:  $annotation_count 条 → -$ann_penalty"
echo "  已知 API:  $api_count 条 → -$api_penalty"
echo "  ---------------------------"
echo "  类别得分: $score/20"
