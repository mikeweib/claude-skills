#!/bin/bash
# 重复代码检测
# 用法: scan-duplicate-code.sh [project_dir]
# 输出: 按子类型分组的 file:line 格式结果 + 扣分汇总
#
# 检测: 完全重复文件 / 复制粘贴代码块 / 高相似度文件

set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: 目录不存在: $PROJECT_DIR"
    exit 1
fi

EXCLUDE_DIRS="-not -path '*/node_modules/*' -not -path '*/vendor/*' -not -path '*/build/*' -not -path '*/dist/*' -not -path '*/.git/*' -not -path '*/target/*' -not -path '*/__pycache__/*' -not -path '*/third_party/*'"

SRC_EGREP='\.(c|cc|cpp|cxx|h|hpp|hh|java|js|jsx|ts|tsx|mjs|go|rs|swift|cs|py)$'

echo "=== 重复代码检测 ==="
echo ""

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# 收集文件列表到临时文件（避免管道 SIGPIPE 问题）
eval "find \"$PROJECT_DIR\" $EXCLUDE_DIRS -type f 2>/dev/null" \
    | grep -E "$SRC_EGREP" 2>/dev/null \
    > "$TEMP_DIR/filelist.txt" || true

TOTAL_FILES=$(wc -l < "$TEMP_DIR/filelist.txt" | tr -d ' ')
echo "  检测源码文件: $TOTAL_FILES 个"
echo ""

# ===== 1. 完全重复文件 (MD5 相同) =====
echo "--- 完全重复文件 (MD5 相同) -3分/对 ---"
echo ""

> "$TEMP_DIR/hashes.txt"
while IFS= read -r f; do
    [ -z "$f" ] && continue
    size=$(wc -c < "$f" 2>/dev/null | tr -d ' ')
    [ "${size:-0}" -lt 50 ] 2>/dev/null && continue
    h=$(md5 -q "$f" 2>/dev/null) || continue
    echo "${h} ${f}"
done < "$TEMP_DIR/filelist.txt" >> "$TEMP_DIR/hashes.txt"

# 统计并显示重复组
sort "$TEMP_DIR/hashes.txt" | awk '
BEGIN { prev = ""; cnt = 0 }
{
    if ($1 == prev) { files[cnt++] = $2 }
    else {
        if (cnt > 1) {
            printf "\n  [重复组, %d 个文件, MD5=%s]\n", cnt, prev
            for (i = 0; i < cnt; i++) printf "    %s\n", files[i]
            total_pairs += cnt - 1
        }
        delete files; files[0] = $2; cnt = 1; prev = $1
    }
}
END {
    if (cnt > 1) {
        printf "\n  [重复组, %d 个文件, MD5=%s]\n", cnt, prev
        for (i = 0; i < cnt; i++) printf "    %s\n", files[i]
        total_pairs += cnt - 1
    }
    print ""
    print total_pairs + 0
}
' > "$TEMP_DIR/dup_output.txt"

# 提取最后一行（统计值），其余为显示内容
dup_file_count=$(tail -1 "$TEMP_DIR/dup_output.txt")
sed -e '$d' "$TEMP_DIR/dup_output.txt" 2>/dev/null || true

echo "  重复文件对: $dup_file_count"
echo ""

# ===== 2. 复制粘贴代码块 (>=6 行连续相同) =====
echo "--- 复制粘贴代码块 (>=6 行连续相同) -2分/块 ---"
echo ""

> "$TEMP_DIR/windows.txt"

# 取前 300 个文件做滑动窗口分析
head -300 "$TEMP_DIR/filelist.txt" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    perl -ne '
    BEGIN { $ws = 6; $wi = 0; }
    chomp;
    s/^\s+|\s+$//g;
    next if /^$/;
    next if /^[{}();,\[\]]$/;
    next if /^#/;
    $win[$wi++ % $ws] = $_;
    if ($wi >= $ws) {
        $cb = join("\n", map { $win[($wi - $ws + $_) % $ws] } (0..$ws-1));
        $h = 0; $h = ($h * 31 + ord()) & 0x7FFFFFFF for split(//, $cb);
        print $h . " " . $ARGV . ":" . ($. - $ws + 1) . "\n";
    }
    ' "$f" 2>/dev/null
done >> "$TEMP_DIR/windows.txt" || true

paste_block_count=0
if [ -s "$TEMP_DIR/windows.txt" ]; then
    sort -t' ' -k1,1 "$TEMP_DIR/windows.txt" | awk '
    BEGIN { prev = ""; cnt = 0; max_show = 5; blocks = 0 }
    {
        if ($1 == prev) { locs[cnt++] = $0 }
        else {
            if (cnt > 1) {
                has_diff = 0
                for (i = 0; i < cnt && !has_diff; i++) {
                    split(locs[i], a, " ")
                    for (j = i + 1; j < cnt && !has_diff; j++) {
                        split(locs[j], b, " ")
                        if (a[2] != b[2]) has_diff = 1
                    }
                }
                if (has_diff) {
                    blocks++
                    show = (cnt > max_show ? max_show : cnt)
                    printf "  [复制块 #%d, %d 处]\n", blocks, cnt
                    for (i = 0; i < show; i++) {
                        sub(/^[^ ]+ /, "", locs[i])
                        printf "    %s\n", locs[i]
                    }
                    if (cnt > max_show) printf "    ... 还有 %d 处\n", cnt - max_show
                    print ""
                }
            }
            delete locs; locs[0] = $0; cnt = 1; prev = $1
        }
    }
    END {
        if (cnt > 1) {
            has_diff = 0
            for (i = 0; i < cnt && !has_diff; i++) {
                split(locs[i], a, " ")
                for (j = i + 1; j < cnt && !has_diff; j++) {
                    split(locs[j], b, " ")
                    if (a[2] != b[2]) has_diff = 1
                }
            }
            if (has_diff) {
                blocks++
                show = (cnt > max_show ? max_show : cnt)
                printf "  [复制块 #%d, %d 处]\n", blocks, cnt
                for (i = 0; i < show; i++) {
                    sub(/^[^ ]+ /, "", locs[i])
                    printf "    %s\n", locs[i]
                }
                if (cnt > max_show) printf "    ... 还有 %d 处\n", cnt - max_show
            }
        }
        print ""
        print blocks + 0
    }
    ' > "$TEMP_DIR/blocks_output.txt"
    paste_block_count=$(tail -1 "$TEMP_DIR/blocks_output.txt" 2>/dev/null || true)
    paste_block_count="${paste_block_count:-0}"
    sed -e '$d' "$TEMP_DIR/blocks_output.txt" 2>/dev/null || true
fi

echo "  复制粘贴块: $paste_block_count"
echo ""

# ===== 3. 高相似度文件 =====
echo "--- 高相似度文件 (>80% 行共享率) -1分/对 ---"
echo ""

# 检测常见的复制命名模式
similar_count=$(grep -cE '\([0-9]+\)\.|_copy[0-9]*\.|-copy[0-9]*\.|_v[0-9]+\.' "$TEMP_DIR/filelist.txt" 2>/dev/null || true)
similar_count="${similar_count:-0}"
# 去除可能的多行结果（grep -c 在无匹配时输出 0 且 exit 1，|| true 确保不中断）

# 列出检测到的命名模式文件
grep -E '\([0-9]+\)\.|_copy[0-9]*\.|-copy[0-9]*\.|_v[0-9]+\.' "$TEMP_DIR/filelist.txt" 2>/dev/null | while IFS= read -r f; do
    echo "    $f"
done || true

# 检测同目录下大小相近的相似文件对（采样处理）
head -200 "$TEMP_DIR/filelist.txt" > "$TEMP_DIR/sample_files.txt"

# 按目录分组，对两两组合做相似度检测
cat "$TEMP_DIR/sample_files.txt" | while IFS= read -r f; do
    dirname "$f"
done | sort -u | while IFS= read -r d; do
    grep -F "$d/" "$TEMP_DIR/sample_files.txt" 2>/dev/null | sort > "$TEMP_DIR/dir_files.txt" || continue
    count=$(wc -l < "$TEMP_DIR/dir_files.txt" | tr -d ' ')
    [ "$count" -lt 2 ] 2>/dev/null && continue
    # 两两组合
    awk -v tmp="$TEMP_DIR" '
    { files[NR] = $0 }
    END {
        pairs = 0
        for (i = 1; i <= NR && pairs < 20; i++) {
            for (j = i + 1; j <= NR && pairs < 20; j++) {
                # 只比较同扩展名
                split(files[i], a, ".")
                split(files[j], b, ".")
                if (a[length(a)] == b[length(b)]) {
                    print files[i] "|" files[j]
                    pairs++
                }
            }
        }
    }' "$TEMP_DIR/dir_files.txt"
done 2>/dev/null | while IFS='|' read -r f1 f2; do
    [ -z "$f1" ] || [ -z "$f2" ] && continue
    size1=$(wc -l < "$f1" 2>/dev/null | tr -d ' ')
    size2=$(wc -l < "$f2" 2>/dev/null | tr -d ' ')
    [ "${size1:-0}" -lt 20 ] 2>/dev/null && continue
    [ "${size2:-0}" -lt 20 ] 2>/dev/null && continue
    max_sz=$(( size1 > size2 ? size1 : size2 ))
    min_sz=$(( size1 < size2 ? size1 : size2 ))
    [ "$max_sz" -eq 0 ] 2>/dev/null && continue
    diff_ratio=$(( (max_sz - min_sz) * 100 / max_sz ))
    [ "$diff_ratio" -gt 30 ] 2>/dev/null && continue
    shared=$(comm -12 <(sort "$f1" 2>/dev/null || true) <(sort "$f2" 2>/dev/null || true) | wc -l | tr -d ' ')
    [ "$min_sz" -eq 0 ] 2>/dev/null && continue
    similarity=$(( shared * 100 / min_sz ))
    if [ "$similarity" -gt 80 ] 2>/dev/null; then
        echo "  $f1 ($size1 行)"
        echo "  $f2 ($size2 行) 相似度 ${similarity}%"
        echo ""
    fi
done 2>/dev/null || true

echo "  高相似度文件 (命名模式): $similar_count"
echo ""

# ===== 扣分计算 =====
dup_penalty=0
[ "${dup_file_count:-0}" -gt 0 ] && dup_penalty=$((dup_file_count * 3 > 8 ? 8 : dup_file_count * 3))

paste_penalty=0
[ "${paste_block_count:-0}" -gt 0 ] && paste_penalty=$((paste_block_count * 2 > 7 ? 7 : paste_block_count * 2))

similar_penalty=0
[ "${similar_count:-0}" -gt 0 ] && similar_penalty=$((similar_count * 1 > 5 ? 5 : similar_count * 1))

total_penalty=$((dup_penalty + paste_penalty + similar_penalty))
score=$((20 - total_penalty > 0 ? 20 - total_penalty : 0))

echo "=== 扣分汇总 ==="
echo "  完全重复文件:     $dup_file_count 对 → -$dup_penalty"
echo "  复制粘贴块:       $paste_block_count 块 → -$paste_penalty"
echo "  高相似度文件:     $similar_count 对 → -$similar_penalty"
echo "  ----------------------------------------"
echo "  类别得分: $score/20"
