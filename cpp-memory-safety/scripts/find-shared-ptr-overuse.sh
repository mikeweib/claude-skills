#!/bin/bash
# 查找 std::shared_ptr 过度使用
# 用法: find-shared-ptr-overuse.sh [directory] [--webrtc]
# --webrtc: 检查 WebRTC 项目中是否误用 std::shared_ptr（应使用 rtc::scoped_refptr）

set -euo pipefail

DIR="${1:-.}"
WEBRTC_MODE=false

# 解析参数
for arg in "$@"; do
    case "$arg" in
        --webrtc) WEBRTC_MODE=true ;;
        *) DIR="$arg" ;;
    esac
done

if [ ! -d "$DIR" ]; then
    echo "Error: directory not found: $DIR"
    exit 1
fi

echo "Scanning: $DIR"
echo ""

# shared_ptr 声明
grep -rn 'std::shared_ptr' "$DIR" \
    --include='*.cc' --include='*.cpp' --include='*.cxx' \
    --include='*.h' --include='*.hpp' --include='*.hh' \
    --include='*.mm' 2>/dev/null \
    | grep -v '^\s*//' | grep -v '^\s*\*' > /tmp/sp_decl.txt || true

# make_shared 调用
grep -rn 'std::make_shared' "$DIR" \
    --include='*.cc' --include='*.cpp' --include='*.cxx' \
    --include='*.h' --include='*.hpp' --include='*.hh' 2>/dev/null \
    | grep -v '^\s*//' | grep -v '^\s*\*' > /tmp/sp_make.txt || true

sp_decl_count=$(wc -l < /tmp/sp_decl.txt 2>/dev/null || echo 0)
sp_make_count=$(wc -l < /tmp/sp_make.txt 2>/dev/null || echo 0)

if [ "$sp_decl_count" -eq 0 ] && [ "$sp_make_count" -eq 0 ]; then
    echo "No std::shared_ptr usage found."
    rm -f /tmp/sp_decl.txt /tmp/sp_make.txt
    exit 0
fi

echo "=== std::shared_ptr 声明 ($sp_decl_count 处) ==="
if [ "$sp_decl_count" -gt 0 ]; then
    cat /tmp/sp_decl.txt
else
    echo "  (none)"
fi
echo ""

echo "=== std::make_shared 调用 ($sp_make_count 处) ==="
if [ "$sp_make_count" -gt 0 ]; then
    cat /tmp/sp_make.txt
else
    echo "  (none)"
fi
echo ""

# 按文件统计
if [ "$sp_decl_count" -gt 0 ]; then
    echo "=== 按文件统计 ==="
    cat /tmp/sp_decl.txt | awk -F: '{print $1}' | sort | uniq -c | sort -rn
    echo ""
fi

# WebRTC 特殊检查
if $WEBRTC_MODE; then
    echo "=== WebRTC 检查: 禁止使用 std::shared_ptr ==="
    if [ "$sp_decl_count" -gt 0 ] || [ "$sp_make_count" -gt 0 ]; then
        echo "  ERROR: WebRTC 项目检测到 std::shared_ptr 使用！"
        echo "  应改用 rtc::scoped_refptr<T>，对象继承 rtc::RefCountInterface"
        echo ""
        # 列出文件
        cat /tmp/sp_decl.txt /tmp/sp_make.txt 2>/dev/null | awk -F: '{print $1}' | sort -u | while read f; do
            echo "  $f"
        done
    else
        echo "  OK: 未使用 std::shared_ptr"
    fi
    echo ""
fi

# 过度使用分析（非 WebRTC 模式）
if ! $WEBRTC_MODE; then
    echo "=== 过度使用分析 ==="
    if [ "$sp_decl_count" -gt 10 ]; then
        echo "  WARNING: shared_ptr 声明超过 10 处 ($sp_decl_count)，检查是否有可改用 unique_ptr 的情况"
    fi

    # 检查作为函数参数传递的 shared_ptr（按值传递 shared_ptr 开销大）
    param_count=$(grep -rn 'std::shared_ptr<.*>[[:space:]]*[a-z_]' "$DIR" \
        --include='*.h' --include='*.hpp' --include='*.hh' 2>/dev/null \
        | grep -v 'const.*&' | grep -v '^\s*//' | wc -l || echo 0)
    if [ "$param_count" -gt 0 ]; then
        echo "  NOTE: $param_count 处 shared_ptr 按值传递（非 const&），考虑改为 const& 或 unique_ptr"
    fi

    echo "  提示: 能用 unique_ptr 的场景不需要 shared_ptr 的引用计数开销"
fi

rm -f /tmp/sp_decl.txt /tmp/sp_make.txt
