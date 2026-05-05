#!/bin/bash
# 交叉验证 GN target 的 deps/public_deps 与 header #include 的一致性
# 用法: check-deps-headers.sh <BUILD.gn> <target_name> [--source-root <path>]
# 输出: public header include 了但不在 public_deps 中的模块

set -euo pipefail

GN_FILE="${1:-}"
TARGET="${2:-}"
SOURCE_ROOT="${3:-$(pwd)}"

if [ -z "$GN_FILE" ] || [ -z "$TARGET" ]; then
    echo "Usage: check-deps-headers.sh <BUILD.gn> <target_name> [--source-root <path>]"
    exit 1
fi

if [ ! -f "$GN_FILE" ]; then
    echo "Error: file not found: $GN_FILE"
    exit 1
fi

GN_DIR=$(dirname "$GN_FILE")
echo "GN file:   $GN_FILE"
echo "Target:    $TARGET"
echo "Directory: $GN_DIR"
echo ""

# ===== 1. 解析 target 的 deps 和 public_deps =====

extract_deps() {
    local field="$1"
    awk -v field="$field" '
    BEGIN { in_target = 0; brace = 0; target_brace = 0 }
    $0 ~ target_name_pattern {
        in_target = 1
    }
    in_target {
        n = split($0, chars, "")
        for (i = 1; i <= n; i++) {
            if (chars[i] == "{") brace++
            else if (chars[i] == "}") brace--
        }
        if (brace == 0) in_target = 0
    }
    ' target_name_pattern="\"$TARGET\"" field="$field" "$GN_FILE" 2>/dev/null
}

# 简化: 用 grep + awk 提取 deps 和 public_deps
TARGET_DIR=$(dirname "$GN_FILE")

# 提取 target 块的内容
# 找到 target_name 的定义，读取直到配对的 }
target_content=$(awk -v t="$TARGET" '
BEGIN { in_target = 0; brace = 0; started = 0 }
/^[[:space:]]*(source_set|static_library|shared_library|executable|group|rtc_source_set|rtc_static_library|rtc_shared_library|component|test)\(/ {
    if ($0 ~ ("\"" t "\"")) {
        in_target = 1
        started = 1
    }
}
in_target {
    print $0
    n = split($0, chars, "")
    for (i = 1; i <= n; i++) {
        if (chars[i] == "{") brace++
        else if (chars[i] == "}") brace--
    }
    if (started && brace == 0) in_target = 0
}
' "$GN_FILE" 2>/dev/null)

if [ -z "$target_content" ]; then
    echo "Error: target \"$TARGET\" not found in $GN_FILE"
    exit 1
fi

# 提取 deps 列表
echo "$target_content" | grep -oP '(public_)?deps\s*\+?=\s*\[.*?\]' 2>/dev/null \
    | grep -oP '"(.*?)"' | sed 's/"//g' > /tmp/gn_deps.txt || true

# 提取 public_deps 列表
echo "$target_content" | grep -oP 'public_deps\s*\+?=\s*\[.*?\]' 2>/dev/null \
    | grep -oP '"(.*?)"' | sed 's/"//g' > /tmp/gn_public_deps.txt || true

echo "=== deps ==="
if [ -s /tmp/gn_deps.txt ]; then
    cat /tmp/gn_deps.txt | sed 's/^/  /'
else
    echo "  (none)"
fi
echo ""

echo "=== public_deps ==="
if [ -s /tmp/gn_public_deps.txt ]; then
    cat /tmp/gn_public_deps.txt | sed 's/^/  /'
else
    echo "  (none)"
fi
echo ""

# ===== 2. 查找 public headers =====

# 提取 sources 找头文件
echo "$target_content" | grep -oP 'sources\s*\+?=\s*\[.*?\]' 2>/dev/null \
    | grep -oP '"(.*?)"' | sed 's/"//g' > /tmp/gn_sources.txt || true

# 提取 public 字段
echo "$target_content" | grep -oP 'public\s*\+?=\s*\[.*?\]' 2>/dev/null \
    | grep -oP '"(.*?)"' | sed 's/"//g' > /tmp/gn_public_sources.txt || true

# 确定 public headers（public 字段 + 非 _impl 的 .h 文件）
public_headers=""
if [ -s /tmp/gn_public_sources.txt ]; then
    public_headers=$(cat /tmp/gn_public_sources.txt)
fi

# 从 sources 中补充 public headers（非 _impl、非 _internal、非 _test 的 .h 文件）
if [ -s /tmp/gn_sources.txt ]; then
    while IFS= read -r src; do
        if [[ "$src" == *.h ]] && [[ ! "$src" =~ _(impl|internal|test|unittest|mock) ]]; then
            # 排除明显的私有 header
            if [[ ! "$src" =~ _private ]]; then
                public_headers="$public_headers"$'\n'"$src"
            fi
        fi
    done < /tmp/gn_sources.txt
fi

public_headers=$(echo "$public_headers" | sort -u | grep -v '^$' || true)

echo "=== public headers (推断) ==="
if [ -z "$public_headers" ]; then
    echo "  (none found)"
else
    echo "$public_headers" | sed 's/^/  /'
fi
echo ""

# ===== 3. grep public headers 中的 #include =====

# 提取目标所在工程的根目录
# 假设: 如果 deps 中有 //xxx 格式的路径，提取出这些路径的顶层目录作为"模块名"
WORKSPACE_ROOT="$SOURCE_ROOT"
# 尝试向上找 .gn root
gn_root="$GN_DIR"
while [ "$gn_root" != "/" ] && [ ! -f "$gn_root/.gn" ]; do
    gn_root=$(dirname "$gn_root")
done
if [ -f "$gn_root/.gn" ]; then
    WORKSPACE_ROOT="$gn_root"
fi

> /tmp/gn_header_includes.txt

while IFS= read -r header; do
    [ -z "$header" ] && continue
    header_path="$GN_DIR/$header"
    if [ -f "$header_path" ]; then
        # 提取 #include
        grep -oP '#include\s+"(.*?)"' "$header_path" 2>/dev/null \
            | sed 's/#include "//;s/"//' >> /tmp/gn_header_includes.txt || true
    fi
done <<< "$public_headers"

if [ ! -s /tmp/gn_header_includes.txt ]; then
    echo "=== 交叉验证 ==="
    echo "  (无 public header 或 header 中无 #include，无需验证)"
    rm -f /tmp/gn_deps.txt /tmp/gn_public_deps.txt /tmp/gn_sources.txt /tmp/gn_public_sources.txt /tmp/gn_header_includes.txt
    exit 0
fi

echo "=== public header 中的 #include ==="
sort -u /tmp/gn_header_includes.txt | sed 's/^/  /'
echo ""

# ===== 4. 反查 include 对应的目标模块 =====

# 对每个 include，找到它所属的 BUILD.gn target
# 策略: 在 WORKSPACE_ROOT 中搜索提供该 header 的 BUILD.gn target
echo "=== 依赖交叉验证 ==="
issues=0

while IFS= read -r include_path; do
    [ -z "$include_path" ] && continue
    # 找到包含此 header 的源文件
    header_full=$(find "$WORKSPACE_ROOT" -path "*/$include_path" -type f 2>/dev/null | head -1)
    if [ -z "$header_full" ]; then
        # 外部/系统 header，跳过
        continue
    fi

    # 找到该 header 最近的 BUILD.gn
    header_dir=$(dirname "$header_full")
    owning_build="$header_dir/BUILD.gn"

    # 在 deps 和 public_deps 中查找是否引用了相关的 target
    # 提取 include 路径的顶层目录作为可能的模块标识
    include_short=$(echo "$include_path" | cut -d'/' -f1)
    include_dir=$(dirname "$include_path")

    # 检查 deps/public_deps 中是否有相关 target
    found_dep=false
    found_public_dep=false

    # 检查 public_deps
    while IFS= read -r dep; do
        [ -z "$dep" ] && continue
        # 匹配 deps 中的 target 名是否与 include 路径相关
        if echo "$include_path" | grep -qF "$dep" 2>/dev/null; then
            found_public_dep=true
            break
        fi
        # 也检查 deps 路径中的目录名是否匹配 include 路径
        dep_dir=$(echo "$dep" | cut -d':' -f1 | sed 's|//||')
        dep_name=$(echo "$dep" | cut -d':' -f2)
        if echo "$include_dir" | grep -qF "$dep_name" 2>/dev/null; then
            found_public_dep=true
            break
        fi
    done < /tmp/gn_public_deps.txt 2>/dev/null

    # 检查 deps
    while IFS= read -r dep; do
        [ -z "$dep" ] && continue
        if echo "$include_path" | grep -qF "$dep" 2>/dev/null; then
            found_dep=true
            break
        fi
        dep_dir=$(echo "$dep" | cut -d':' -f1 | sed 's|//||')
        dep_name=$(echo "$dep" | cut -d':' -f2)
        if echo "$include_dir" | grep -qF "$dep_name" 2>/dev/null; then
            found_dep=true
            break
        fi
    done < /tmp/gn_deps.txt 2>/dev/null

    # 也检查 deps 是否通过 //path:target 格式包含 include 路径
    all_deps_file="/tmp/gn_all_deps.txt"
    cat /tmp/gn_deps.txt /tmp/gn_public_deps.txt 2>/dev/null > "$all_deps_file" || true

    while IFS= read -r dep; do
        [ -z "$dep" ] && continue
        # dep 格式: 可能是 //path/to:target 或 :target
        dep_path=$(echo "$dep" | cut -d':' -f1)
        dep_path="${dep_path#//}"
        if echo "$include_path" | grep -qF "$dep_path" 2>/dev/null; then
            found_dep=true
            break
        fi
    done < "$all_deps_file" 2>/dev/null

    if $found_public_dep; then
        echo "  OK     $include_path → public_deps"
    elif $found_dep; then
        echo "  WARN   $include_path → 在 deps 中但不在 public_deps 中（public header include 了此模块）"
        issues=$((issues + 1))
    else
        echo "  MISSING $include_path → 未在 deps/public_deps 中声明"
        issues=$((issues + 1))
    fi
done < <(sort -u /tmp/gn_header_includes.txt)

echo ""
echo "=== 汇总 ==="
echo "  问题数: $issues"

rm -f /tmp/gn_deps.txt /tmp/gn_public_deps.txt /tmp/gn_sources.txt /tmp/gn_public_sources.txt /tmp/gn_header_includes.txt /tmp/gn_all_deps.txt

if [ "$issues" -gt 0 ]; then
    exit 1
fi
