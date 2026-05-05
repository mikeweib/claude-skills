#!/bin/bash
# 验证 BUILD.gn / .gni 中所有 import() 路径是否存在
# 用法: validate-imports.sh [directory|file] [--source-root <path>]
# 输出: 缺失的 import 路径列表

set -euo pipefail

TARGET="${1:-.}"
SOURCE_ROOT="${2:-$(pwd)}"

# 解析 --source-root
if [[ "${2:-}" == --source-root=* ]]; then
    SOURCE_ROOT="${2#--source-root=}"
elif [[ "${2:-}" == --source-root ]] && [ -n "${3:-}" ]; then
    SOURCE_ROOT="$3"
fi

if [ -f "$TARGET" ]; then
    GN_FILES=("$TARGET")
elif [ -d "$TARGET" ]; then
    mapfile -t GN_FILES < <(find "$TARGET" -type f \( -name 'BUILD.gn' -o -name '*.gni' \) 2>/dev/null)
else
    echo "Error: target not found: $TARGET"
    exit 1
fi

if [ ${#GN_FILES[@]} -eq 0 ]; then
    echo "No GN files found."
    exit 0
fi

echo "Scanning ${#GN_FILES[@]} GN file(s)..."
echo "Source root: $SOURCE_ROOT"
echo ""

total_imports=0
missing_count=0

for gn_file in "${GN_FILES[@]}"; do
    # 提取 import() 路径
    imports=$(grep -o 'import(".*")' "$gn_file" 2>/dev/null | sed 's/import("\(.*\)")/\1/' || true)

    if [ -z "$imports" ]; then
        continue
    fi

    while IFS= read -r import_path; do
        total_imports=$((total_imports + 1))
        # 将 GN 路径转为文件系统路径
        if [[ "$import_path" == //* ]]; then
            fs_path="$SOURCE_ROOT/${import_path#//}"
        else
            gn_dir=$(dirname "$gn_file")
            fs_path="$gn_dir/$import_path"
            fs_path=$(cd "$gn_dir" 2>/dev/null && realpath --relative-to="$SOURCE_ROOT" "$import_path" 2>/dev/null || echo "$gn_dir/$import_path")
            fs_path="$SOURCE_ROOT/$fs_path"
        fi

        if [ ! -f "$fs_path" ]; then
            echo "MISSING: $gn_file:$import_path"
            echo "  expected: $fs_path"
            missing_count=$((missing_count + 1))
        fi
    done <<< "$imports"
done

echo ""
echo "=== 汇总 ==="
echo "  总 import: $total_imports"
echo "  缺失: $missing_count"

if [ "$missing_count" -gt 0 ]; then
    exit 1
fi
