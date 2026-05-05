#!/bin/bash
# 检查含 raw pointer 成员的 class 是否遵循 Rule of Five
# 用法: check-rule-of-five.sh [directory]
# 输出: 每个违反 Rule of Five 的 class 及其缺失的特殊成员函数

set -euo pipefail

DIR="${1:-.}"
if [ ! -d "$DIR" ]; then
    echo "Error: directory not found: $DIR"
    exit 1
fi

echo "Scanning: $DIR"
echo ""

# 找所有头文件
HEADERS=$(find "$DIR" -type f \( -name '*.h' -o -name '*.hpp' -o -name '*.hh' \) 2>/dev/null | grep -v '/test/' | grep -v '/third_party/' || true)

if [ -z "$HEADERS" ]; then
    echo "No header files found."
    exit 0
fi

# 对每个头文件分析
while IFS= read -r header; do
    # 提取 class/struct 定义及其大括号块（简化处理）
    awk -v file="$header" '
    /^[[:space:]]*(class|struct)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/ {
        in_class = 1
        brace_count = 0
        class_line = NR
        # 提取类名
        match($0, /(class|struct)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)/, arr)
        class_name = arr[2]
        has_raw_ptr = 0
        has_dtor = 0; has_copy_ctor = 0; has_copy_assign = 0
        has_move_ctor = 0; has_move_assign = 0
        has_delete_copy = 0; has_delete_move = 0
        class_body = ""
        next
    }
    in_class {
        # 计算大括号层级
        for (i = 1; i <= length($0); i++) {
            c = substr($0, i, 1)
            if (c == "{") brace_count++
            else if (c == "}") brace_count--
        }
        class_body = class_body $0 "\n"

        # 检测 raw pointer 成员
        if ($0 ~ /[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\*[[:space:]]+[a-z_][A-Za-z0-9_]*;/) {
            has_raw_ptr = 1
        }

        # 检测特殊成员函数
        if ($0 ~ ("~" class_name "[[:space:]]*\\(")) has_dtor = 1
        if ($0 ~ (class_name "[[:space:]]*\\([[:space:]]*const[[:space:]]+" class_name "[[:space:]]*&")) has_copy_ctor = 1
        if ($0 ~ (class_name "[[:space:]]*\\([[:space:]]*" class_name "[[:space:]]*&&")) has_move_ctor = 1
        if ($0 ~ ("operator=[[:space:]]*\\([[:space:]]*const[[:space:]]+" class_name "[[:space:]]*&")) has_copy_assign = 1
        if ($0 ~ ("operator=[[:space:]]*\\([[:space:]]*" class_name "[[:space:]]*&&")) has_move_assign = 1
        if ($0 ~ "=[[:space:]]*delete") {
            if ($0 ~ "copy|Copy") has_delete_copy = 1
            if ($0 ~ "move|Move") has_delete_move = 1
        }

        if (brace_count == 0) {
            in_class = 0
            if (has_raw_ptr) {
                missing = ""
                if (!has_dtor) missing = missing " dtor"
                if (!has_copy_ctor && !has_delete_copy) missing = missing " copy-ctor"
                if (!has_copy_assign && !has_delete_copy) missing = missing " copy-assign"
                if (!has_move_ctor && !has_delete_move) missing = missing " move-ctor"
                if (!has_move_assign && !has_delete_move) missing = missing " move-assign"
                if (missing != "") {
                    printf "%s:%d class %s missing:%s\n", file, class_line, class_name, missing
                }
            }
        }
    }
    ' "$header" 2>/dev/null || true
done <<< "$HEADERS"
