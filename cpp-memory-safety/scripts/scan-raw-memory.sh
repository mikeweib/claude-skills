#!/bin/bash
# 扫描 C++ 源码中的裸内存操作
# 用法: scan-raw-memory.sh [directory]
# 输出: 按操作类型分组的 file:line 列表

set -euo pipefail

DIR="${1:-.}"
if [ ! -d "$DIR" ]; then
    echo "Error: directory not found: $DIR"
    exit 1
fi

FILE_PATTERN='\.(cc|cpp|cxx|h|hpp|hh|mm|m)$'

matches() {
    local pattern="$1"
    local label="$2"
    local result
    result=$(grep -rn "$pattern" "$DIR" --include='*.cc' --include='*.cpp' --include='*.cxx' \
        --include='*.h' --include='*.hpp' --include='*.hh' --include='*.mm' --include='*.m' 2>/dev/null \
        | grep -v '^\s*//' | grep -v '\*\/' | grep -v '^\s*\*' | grep -v '#define' || true)
    echo "=== $label ==="
    if [ -z "$result" ]; then
        echo "  (none)"
    else
        echo "$result"
    fi
    echo ""
}

echo "Scanning: $DIR"
echo ""

# 裸 new（排除 make_unique/make_shared 和 placement new）
grep -rn '\bnew\b' "$DIR" --include='*.cc' --include='*.cpp' --include='*.cxx' \
    --include='*.h' --include='*.hpp' --include='*.hh' --include='*.mm' --include='*.m' 2>/dev/null \
    | grep -v '\bmake_unique\b' \
    | grep -v '\bmake_shared\b' \
    | grep -v '^\s*//' \
    | grep -v '^\s*\*' \
    | grep -v '#define' \
    > /tmp/raw_new.txt || true

if [ -s /tmp/raw_new.txt ]; then
    echo "=== new (排除 make_unique/make_shared) ==="
    cat /tmp/raw_new.txt
else
    echo "=== new ==="
    echo "  (none)"
fi
echo ""

# new[] 数组分配
grep -rn '\bnew\b.*\[' "$DIR" --include='*.cc' --include='*.cpp' --include='*.cxx' \
    --include='*.h' --include='*.hpp' --include='*.hh' 2>/dev/null \
    | grep -v '^\s*//' | grep -v '^\s*\*' | grep -v '#define' > /tmp/raw_new_array.txt || true
if [ -s /tmp/raw_new_array.txt ]; then
    echo "=== new[] 数组分配 ==="
    cat /tmp/raw_new_array.txt
else
    echo "=== new[] 数组分配 ==="
    echo "  (none)"
fi
echo ""

# delete
grep -rn '\bdelete\b' "$DIR" --include='*.cc' --include='*.cpp' --include='*.cxx' \
    --include='*.h' --include='*.hpp' --include='*.hh' 2>/dev/null \
    | grep -v '^\s*//' | grep -v '^\s*\*' | grep -v '#define' > /tmp/raw_delete.txt || true
if [ -s /tmp/raw_delete.txt ]; then
    echo "=== delete ==="
    cat /tmp/raw_delete.txt
else
    echo "=== delete ==="
    echo "  (none)"
fi
echo ""

# delete[] 数组释放
grep -rn '\bdelete\[\]' "$DIR" --include='*.cc' --include='*.cpp' --include='*.cxx' \
    --include='*.h' --include='*.hpp' --include='*.hh' 2>/dev/null \
    | grep -v '^\s*//' | grep -v '^\s*\*' > /tmp/raw_delete_array.txt || true
if [ -s /tmp/raw_delete_array.txt ]; then
    echo "=== delete[] 数组释放 ==="
    cat /tmp/raw_delete_array.txt
else
    echo "=== delete[] 数组释放 ==="
    echo "  (none)"
fi
echo ""

# malloc/free/realloc
grep -rn '\bmalloc\b\|\bfree\b\|\brealloc\b\|\bcalloc\b' "$DIR" \
    --include='*.cc' --include='*.cpp' --include='*.cxx' \
    --include='*.h' --include='*.hpp' --include='*.hh' \
    --include='*.mm' --include='*.m' 2>/dev/null \
    | grep -v '^\s*//' | grep -v '^\s*\*' | grep -v '#define' > /tmp/raw_c.txt || true
if [ -s /tmp/raw_c.txt ]; then
    echo "=== malloc/free/realloc/calloc ==="
    cat /tmp/raw_c.txt
else
    echo "=== malloc/free/realloc/calloc ==="
    echo "  (none)"
fi
echo ""

# 统计
new_count=$(wc -l < /tmp/raw_new.txt 2>/dev/null || echo 0)
delete_count=$(wc -l < /tmp/raw_delete.txt 2>/dev/null || echo 0)
c_count=$(wc -l < /tmp/raw_c.txt 2>/dev/null || echo 0)
echo "=== 汇总 ==="
echo "  new:        $new_count"
echo "  delete:     $delete_count"
echo "  malloc/free: $c_count"

rm -f /tmp/raw_new.txt /tmp/raw_delete.txt /tmp/raw_new_array.txt /tmp/raw_delete_array.txt /tmp/raw_c.txt
