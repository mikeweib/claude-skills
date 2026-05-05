#!/bin/bash
# Harness 评分环境预检
# 用法: preflight-check.sh [project_dir]
# 输出: ECC 安装状态 / 审计引擎可用性 / 项目 harness 基础状态

set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
ECC_CACHE="${HOME}/.claude/plugins/cache/ecc"

echo "=== Harness 评分环境预检 ==="
echo ""

# ===== 1. ECC 插件检查 =====
echo "--- ECC 插件 ---"
if [ -d "$ECC_CACHE" ]; then
    echo "  [OK] ECC 缓存目录存在: $ECC_CACHE"

    # 找最新版本
    latest=$(ls -d "$ECC_CACHE"/everything-claude-code/*/ 2>/dev/null | sort -V | tail -1 || true)
    if [ -n "$latest" ]; then
        version=$(basename "$latest")
        echo "  [OK] ECC 版本: $version"

        # 检查审计引擎
        audit_script="$latest/scripts/harness-audit.js"
        if [ -f "$audit_script" ]; then
            echo "  [OK] 审计引擎: $audit_script"
        else
            echo "  [FAIL] 审计引擎未找到: $audit_script"
            echo "    可能路径: $(find "$ECC_CACHE" -name 'harness-audit.js' 2>/dev/null || echo '(none)')"
        fi
    else
        echo "  [FAIL] 未找到 ECC 安装 (everything-claude-code)"
    fi
else
    echo "  [FAIL] ECC 缓存目录不存在: $ECC_CACHE"
    echo "  建议: 安装 ECC 插件后重试"
fi
echo ""

# ===== 2. 项目环境检查 =====
echo "--- 项目环境 ($PROJECT_DIR) ---"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "  [FAIL] 项目目录不存在"
    exit 1
fi

# CLAUDE.md / AGENTS.md
if [ -f "$PROJECT_DIR/CLAUDE.md" ] || [ -f "$PROJECT_DIR/AGENTS.md" ]; then
    echo "  [OK] 项目指令文件: $(ls "$PROJECT_DIR"/{CLAUDE,AGENTS}.md 2>/dev/null || true)"
else
    echo "  [MISS] 缺少项目指令文件 (CLAUDE.md / AGENTS.md)"
fi

# .claude/settings.json
if [ -f "$PROJECT_DIR/.claude/settings.json" ]; then
    echo "  [OK] 项目 settings.json"
else
    echo "  [MISS] 缺少 .claude/settings.json"
fi

# .claude/ 本地覆盖
claude_dir="$PROJECT_DIR/.claude"
if [ -d "$claude_dir" ]; then
    overrides=""
    for sub in agents skills commands; do
        if [ -d "$claude_dir/$sub" ] && [ "$(ls -A "$claude_dir/$sub" 2>/dev/null)" ]; then
            overrides="$overrides $sub"
        fi
    done
    if [ -n "$overrides" ]; then
        echo "  [OK] 本地覆盖:$overrides"
    else
        echo "  [NOTE] .claude/ 存在但无本地覆盖 (agents/skills/commands)"
    fi
else
    echo "  [MISS] 无 .claude/ 目录"
fi

# .mcp.json
if [ -f "$PROJECT_DIR/.mcp.json" ]; then
    echo "  [OK] .mcp.json"
else
    echo "  [NOTE] 无 .mcp.json"
fi
echo ""

# ===== 3. 质量门禁检查 =====
echo "--- 质量门禁 ---"

# 测试入口
has_test_entry=false
if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -q '"test"' "$PROJECT_DIR/package.json" 2>/dev/null; then
        echo "  [OK] npm test 脚本"
        has_test_entry=true
    fi
fi
# 通用测试文件检查
if ! $has_test_entry; then
    test_files=$(find "$PROJECT_DIR" -maxdepth 3 -type f \( -name '*_test.*' -o -name '*_spec.*' -o -name 'test_*' \) 2>/dev/null | head -5 || true)
    if [ -n "$test_files" ]; then
        echo "  [OK] 测试文件: $(echo "$test_files" | wc -l | tr -d ' ') 个"
        has_test_entry=true
    fi
fi
if ! $has_test_entry; then
    echo "  [MISS] 无测试入口或测试文件"
fi

# CI 工作流
if [ -d "$PROJECT_DIR/.github/workflows" ]; then
    ci_count=$(ls "$PROJECT_DIR/.github/workflows"/*.yml 2>/dev/null | wc -l | tr -d ' ')
    if [ "$ci_count" -gt 0 ]; then
        echo "  [OK] CI 工作流: $ci_count 个"
    else
        echo "  [MISS] 无 CI 工作流"
    fi
else
    echo "  [MISS] 无 .github/workflows/"
fi
echo ""

# ===== 4. 安全检查 =====
echo "--- 安全基础 ---"

if [ -f "$PROJECT_DIR/SECURITY.md" ]; then
    echo "  [OK] SECURITY.md"
else
    echo "  [MISS] 缺少 SECURITY.md"
fi

if [ -f "$PROJECT_DIR/.gitignore" ]; then
    if grep -q '\.env' "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        echo "  [OK] .gitignore 包含 .env"
    else
        echo "  [WARN] .gitignore 未包含 .env"
    fi
else
    echo "  [MISS] 缺少 .gitignore"
fi
echo ""

# ===== 5. 记忆持久化 =====
echo "--- 记忆持久化 ---"

if [ -f "$PROJECT_DIR/.claude/memory.md" ] || [ -d "$PROJECT_DIR/.claude/memory" ]; then
    echo "  [OK] 项目记忆存在"
else
    if [ -d "$PROJECT_DIR/docs/adr" ]; then
        echo "  [OK] ADR 目录存在 (替代记忆机制)"
    else
        echo "  [MISS] 无持久化记忆 (.claude/memory.md 或 docs/adr/)"
    fi
fi
echo ""

# ===== 6. 汇总 =====
echo "=== 状态汇总 ==="

# 快速计分
score=0
max=10

[ -d "$ECC_CACHE" ] && score=$((score + 2))
[ -f "$PROJECT_DIR/CLAUDE.md" ] || [ -f "$PROJECT_DIR/AGENTS.md" ] && score=$((score + 1))
[ -f "$PROJECT_DIR/.claude/settings.json" ] && score=$((score + 1))
$has_test_entry && score=$((score + 1))
[ -d "$PROJECT_DIR/.github/workflows" ] && score=$((score + 1))
[ -f "$PROJECT_DIR/SECURITY.md" ] && score=$((score + 1))
[ -f "$PROJECT_DIR/.gitignore" ] && score=$((score + 1))
[ -f "$PROJECT_DIR/.claude/memory.md" ] || [ -d "$PROJECT_DIR/.claude/memory" ] || [ -d "$PROJECT_DIR/docs/adr" ] && score=$((score + 1))

echo "  预检得分: $score/$max"
echo ""

if [ "$score" -le 2 ]; then
    echo "  等级: F — 几乎无 harness 配置，建议安装 ECC 并创建基础文件"
elif [ "$score" -le 4 ]; then
    echo "  等级: D — 大量缺失，从 CLAUDE.md 和 settings.json 开始"
elif [ "$score" -le 6 ]; then
    echo "  等级: C — 基础存在，补全质量门禁和安全配置"
elif [ "$score" -le 8 ]; then
    echo "  等级: B — 良好，少数项待补全"
else
    echo "  等级: A — 优秀，harness 配置完善"
fi
