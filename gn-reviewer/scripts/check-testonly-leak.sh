#!/bin/bash
# 检查 testonly 泄漏：testonly=true 的 target 是否被非测试 target 依赖
# 用法: check-testonly-leak.sh [directory]
# 输出: testonly 泄漏列表 + guard 不一致

set -euo pipefail

DIR="${1:-.}"
if [ ! -d "$DIR" ]; then
    echo "Error: directory not found: $DIR"
    exit 1
fi

echo "Scanning: $DIR"
echo ""

# ===== 1. 找出所有 testonly 的 target =====
# 收集: file:target_name
> /tmp/gn_testonly.txt

while IFS= read -r gn_file; do
    awk -v file="$gn_file" '
    /^[[:space:]]*(source_set|static_library|shared_library|executable|group|rtc_source_set|rtc_static_library|rtc_shared_library|component|test|if)\(/ {
        # 找到 target 名
        match($0, /"([^"]+)"/, arr)
        current = arr[1]
        brace = 0
        in_target = 1
        body = ""
        next
    }
    in_target {
        body = body $0 "\n"
        n = split($0, chars, "")
        for (i = 1; i <= n; i++) {
            if (chars[i] == "{") brace++
            else if (chars[i] == "}") brace--
        }
        if (brace == 0) {
            in_target = 0
            if (body ~ /testonly[[:space:]]*=[[:space:]]*true/) {
                printf "%s:%s\n", file, current
            }
        }
    }
    ' "$gn_file" 2>/dev/null
done < <(find "$DIR" -name 'BUILD.gn' -o -name '*.gni' | grep -v '/test/' || true) > /tmp/gn_testonly.txt

if [ ! -s /tmp/gn_testonly.txt ]; then
    echo "No testonly targets found."
    rm -f /tmp/gn_testonly.txt
    exit 0
fi

echo "=== testonly targets ($(wc -l < /tmp/gn_testonly.txt | tr -d ' ')) ==="
cat /tmp/gn_testonly.txt | sed 's/^/  /'
echo ""

# ===== 2. 检查每个 testonly target 被谁依赖 =====
echo "=== testonly 泄漏检查 ==="
leaks=0

while IFS= read -r line; do
    gn_file=$(echo "$line" | cut -d: -f1)
    target_name=$(echo "$line" | cut -d: -f2)

    # 搜索谁引用了此 target
    refs=$(grep -rn "\"$target_name\"" "$DIR" --include='BUILD.gn' --include='*.gni' 2>/dev/null \
        | grep -v "^$gn_file" | grep -v '/test/' || true)

    if [ -n "$refs" ]; then
        # 检查每个引用处所在 target 是否也是 testonly
        while IFS= read -r ref; do
            ref_file=$(echo "$ref" | cut -d: -f1)
            ref_line=$(echo "$ref" | cut -d: -f2)

            # 找到该引用所在的 target 定义
            # 向上查找最近的 target 定义
            parent_target=$(awk -v line="$ref_line" '
            NR < line && /^[[:space:]]*(source_set|static_library|shared_library|executable|group|rtc_source_set|rtc_static_library|rtc_shared_library|component|test)\(/ {
                match($0, /"([^"]+)"/, arr)
                last = arr[1]
            }
            END { print last }
            ' "$ref_file" 2>/dev/null)

            if [ -z "$parent_target" ]; then
                parent_target="(unknown)"
            fi

            # 检查 parent_target 是否 testonly
            parent_is_testonly=$(awk -v t="$parent_target" '
            /^[[:space:]]*(source_set|static_library|shared_library|executable|group|rtc_source_set|rtc_static_library|rtc_shared_library|component|test)\(/ {
                match($0, /"([^"]+)"/, arr)
                if (arr[1] == t) { in_target = 1; brace = 0 }
            }
            in_target {
                n = split($0, chars, "")
                for (i = 1; i <= n; i++) {
                    if (chars[i] == "{") brace++
                    else if (chars[i] == "}") brace--
                }
                if (brace == 0) in_target = 0
                if ($0 ~ /testonly[[:space:]]*=[[:space:]]*true/) { found = 1 }
            }
            END { print found ? "yes" : "no" }
            ' "$ref_file" 2>/dev/null)

            if [ "$parent_is_testonly" != "yes" ]; then
                # 检查是否有测试 guard
                # 找到 ref 所在的 if block
                guard=$(awk -v line="$ref_line" '
                NR < line { if (/if[[:space:]]*\(/) { last_if = $0; last_if_line = NR } }
                END { if (line - last_if_line < 10) print last_if; else print "(no guard found)" }
                ' "$ref_file" 2>/dev/null)

                guard_ok=false
                if echo "$guard" | grep -qE 'test|rtc_include.*test'; then
                    guard_ok=true
                    echo "  WARN (guard) $ref_file:$ref_line → $target_name (testonly) 被 $parent_target 引用"
                    echo "        guard: $guard"
                else
                    echo "  LEAK  $ref_file:$ref_line → $target_name (testonly) 被 $parent_target (非 testonly) 引用"
                    echo "        guard: $guard"
                    leaks=$((leaks + 1))
                fi
            fi
        done <<< "$refs"
    fi
done < /tmp/gn_testonly.txt

echo ""
echo "=== 汇总 ==="
echo "  testonly targets: $(wc -l < /tmp/gn_testonly.txt | tr -d ' ')"
echo "  泄漏: $leaks"

rm -f /tmp/gn_testonly.txt

if [ "$leaks" -gt 0 ]; then
    exit 1
fi
