#!/bin/bash
# 查找跨 target 重复的 cflags/ldflags/defines 配置块
# 用法: find-duplicate-configs.sh [directory]
# 输出: 重复的 flag 组合及其所在位置和建议

set -euo pipefail

DIR="${1:-.}"
if [ ! -d "$DIR" ]; then
    echo "Error: directory not found: $DIR"
    exit 1
fi

echo "Scanning: $DIR"
echo ""

declare -A flag_map

# ===== 1. 提取每个 target 中的 flags =====
> /tmp/gn_cflags.txt
> /tmp/gn_ldflags.txt
> /tmp/gn_defines.txt

while IFS= read -r gn_file; do
    awk -v file="$gn_file" '
    /^[[:space:]]*(source_set|static_library|shared_library|executable|group|rtc_source_set|rtc_static_library|rtc_shared_library|component|config|test)\(/ {
        match($0, /"([^"]+)"/, arr)
        current = arr[1]
        in_block = 1; brace = 0
        cflags = ""; ldflags = ""; defines = ""
        next
    }
    in_block {
        n = split($0, chars, "")
        for (i = 1; i <= n; i++) {
            if (chars[i] == "{") brace++
            else if (chars[i] == "}") brace--
        }

        if ($0 ~ /cflags[[:space:]]*\+?=/) {
            # 提取 cflags 中的 flags
            match($0, /cflags[[:space:]]*\+?=[[:space:]]*\[(.*)\]/, arr)
            if (arr[1] != "") {
                cflags = cflags arr[1]
            }
        }
        if ($0 ~ /ldflags[[:space:]]*\+?=/) {
            match($0, /ldflags[[:space:]]*\+?=[[:space:]]*\[(.*)\]/, arr)
            if (arr[1] != "") {
                ldflags = ldflags arr[1]
            }
        }
        if ($0 ~ /defines[[:space:]]*\+?=/) {
            match($0, /defines[[:space:]]*\+?=[[:space:]]*\[(.*)\]/, arr)
            if (arr[1] != "") {
                defines = defines arr[1]
            }
        }

        if (brace == 0) {
            in_block = 0
            if (cflags != "") printf "%s:%s|cflags|%s\n", file, current, cflags
            if (ldflags != "") printf "%s:%s|ldflags|%s\n", file, current, ldflags
            if (defines != "") printf "%s:%s|defines|%s\n", file, current, defines
        }
    }
    ' "$gn_file" 2>/dev/null
done < <(find "$DIR" -name 'BUILD.gn' -o -name '*.gni' | sort) > /tmp/gn_all_flags.txt

if [ ! -s /tmp/gn_all_flags.txt ]; then
    echo "No inline flags found."
    rm -f /tmp/gn_all_flags.txt /tmp/gn_cflags.txt /tmp/gn_ldflags.txt /tmp/gn_defines.txt
    exit 0
fi

# ===== 2. 规范化 flags 并找重复 =====

normalize_flags() {
    # 去除引号、空格规范化
    echo "$1" | tr ',' '\n' | sed 's/^[[:space:]]*"//;s/"[[:space:]]*$//' \
        | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort | tr '\n' ',' | sed 's/,$//'
}

> /tmp/gn_dup.txt

# 分别检查 cflags, ldflags, defines
for flag_type in cflags ldflags defines; do
    grep "|$flag_type|" /tmp/gn_all_flags.txt 2>/dev/null > "/tmp/gn_${flag_type}_only.txt" || true

    if [ ! -s "/tmp/gn_${flag_type}_only.txt" ]; then
        continue
    fi

    # 按归一化后的 flags 分组
    declare -A seen_groups
    while IFS= read -r line; do
        file_target=$(echo "$line" | cut -d'|' -f1)
        flags_raw=$(echo "$line" | cut -d'|' -f3-)
        flags_norm=$(normalize_flags "$flags_raw")

        if [ -z "$flags_norm" ]; then
            continue
        fi

        key="$flag_type:$flags_norm"
        if [ -n "${seen_groups[$key]:-}" ]; then
            seen_groups[$key]="${seen_groups[$key]}, $file_target"
        else
            seen_groups[$key]="$file_target"
        fi
    done < "/tmp/gn_${flag_type}_only.txt"

    # 输出重复项
    for key in "${!seen_groups[@]}"; do
        IFS=',' read -r -a targets <<< "${seen_groups[$key]}"
        if [ ${#targets[@]} -ge 3 ]; then
            flag_type_name=$(echo "$key" | cut -d: -f1)
            flag_content=$(echo "$key" | cut -d: -f2-)
            echo "=== $flag_type_name 重复 (${#targets[@]} 处) ===" >> /tmp/gn_dup.txt
            echo "  flags: $flag_content" >> /tmp/gn_dup.txt
            for t in "${targets[@]}"; do
                echo "    $t" >> /tmp/gn_dup.txt
            done
            echo "  建议: 提取为 config(\"xxx\") {} → configs += [ \":xxx\" ]" >> /tmp/gn_dup.txt
            echo "" >> /tmp/gn_dup.txt
        fi
    done
    unset seen_groups
done

if [ -s /tmp/gn_dup.txt ]; then
    cat /tmp/gn_dup.txt
    dup_count=$(grep -c "^===" /tmp/gn_dup.txt 2>/dev/null || echo 0)
    echo "=== 汇总 ==="
    echo "  重复配置组: $dup_count"
else
    echo "No duplicated flag blocks found (threshold: 3+ occurrences)."
fi

rm -f /tmp/gn_all_flags.txt /tmp/gn_cflags.txt /tmp/gn_ldflags.txt /tmp/gn_defines.txt \
    /tmp/gn_cflags_only.txt /tmp/gn_ldflags_only.txt /tmp/gn_defines_only.txt /tmp/gn_dup.txt
