# Harness 评分类别详解

## 评分引擎

评分由 ECC 确定性审计引擎执行：`scripts/harness-audit.js`（Rubric version: 2026-03-30）。

引擎自动检测目标模式：
- **repo**：目标本身是 ECC 插件仓库（检查 27 项）
- **consumer**：普通项目使用 ECC（检查 11 项）

## 7 类评分标准

### 1. Tool Coverage（工具覆盖）— max 10

衡量 agent harness 工具链的完整程度。

**Consumer 检查项：**

| ID | 权重 | 检查内容 |
|----|------|---------|
| consumer-plugin-install | 4 | ECC 插件已安装在用户或项目下 |
| consumer-project-overrides | 3 | `.claude/` 下有 agents/skills/commands/settings/hooks 中的至少一种 |

**改进路径：**
1. 确保 ECC 已安装
2. 在项目 `.claude/` 下至少创建 `settings.json` 和 `CLAUDE.md`
3. 根据需要添加项目级 agents/skills/commands

### 2. Context Efficiency（上下文效率）— max 10

衡量上下文窗口的利用效率。

**Consumer 检查项：**

| ID | 权重 | 检查内容 |
|----|------|---------|
| consumer-instructions | 3 | 项目有 `CLAUDE.md` / `AGENTS.md` / `.claude/CLAUDE.md` |
| consumer-project-config | 2 | 项目有 `.mcp.json` / `.claude/settings.json` / `.claude/settings.local.json` |

**改进路径：**
1. 创建 `CLAUDE.md` 描述项目信息（技术栈、约定、架构）
2. 创建 `.claude/settings.json` 声明项目级权限和配置

### 3. Quality Gates（质量门禁）— max 10

衡量自动化质量保障体系。

**Consumer 检查项：**

| ID | 权重 | 检查内容 |
|----|------|---------|
| consumer-test-suite | 4 | 项目有 `npm test` 或 test 文件 |
| consumer-ci-workflow | 3 | 项目有 `.github/workflows/` 下的 CI 配置 |

**改进路径：**
1. 在 `package.json` 添加 `"test"` 脚本
2. 添加至少一个 GitHub Actions workflow

### 4. Memory Persistence（记忆持久化）— max 10

衡量项目知识的持久化和传承能力。

**Consumer 检查项：**

| ID | 权重 | 检查内容 |
|----|------|---------|
| consumer-memory-notes | 2 | 项目有 `.claude/memory.md` 或 `docs/adr/` |

**改进路径：**
1. 创建 `.claude/memory.md` 记录项目决策和上下文
2. 或使用 ADR（Architecture Decision Records）在 `docs/adr/` 下

### 5. Eval Coverage（评估覆盖）— max 10

衡量通过自动化评估确保质量的能力。

**Consumer 检查项：**

| ID | 权重 | 检查内容 |
|----|------|---------|
| consumer-eval-coverage | 2 | 项目有 `evals/` 目录或至少 3 个 test 文件 |

**改进路径：**
1. 为核心流程编写测试
2. 使用 `eval-harness` skill 建立回归评估

### 6. Security Guardrails（安全护栏）— max 10

衡量安全防护措施的完善程度。

**Consumer 检查项：**

| ID | 权重 | 检查内容 |
|----|------|---------|
| consumer-security-policy | 2 | 项目有 `SECURITY.md` 或 Dependabot/CodeQL 配置 |
| consumer-secret-hygiene | 2 | `.gitignore` 包含 `.env` |
| consumer-hook-guardrails | 2 | 项目有 hook 护栏配置（PreToolUse 等） |

**改进路径：**
1. 添加 `SECURITY.md`
2. 确保 `.gitignore` 包含 `.env*` 和敏感文件
3. 在 `.claude/settings.json` 中配置 hooks

### 7. Cost Efficiency（成本效率）— max 10

衡量 LLM 使用成本的管控能力。

**Consumer 检查项：** 无内置检查项。

**手动改进建议：**
1. 使用 `cost-aware-llm-pipeline` skill 配置成本感知路由
2. 配置模型路由规则（`model-route` command）
3. 定期审查 token 使用量

## 模式对比

| 维度 | repo 模式 | consumer 模式 |
|------|----------|--------------|
| 目标 | ECC 插件自身 | 使用 ECC 的普通项目 |
| 检查项数 | 27 | 11 |
| 原始满分 | 70 | 29 |
| 最低要求 | 30+ (C 级) | 15+ (C 级) |
| 推荐目标 | 60+ (A 级) | 26+ (A 级) |
| 无意义的类别 | 无 | Cost Efficiency |

## 归一化算法

每个类别的原始分归一化到 0–10：
```
normalized = round((earned / max_in_category) * 10)
```

例如：Tool Coverage 最高 7 分，实际得 4 分 → `round((4/7)*10) = 6/10`

总分 = 所有类别归一化得分之和（最高 60–70，取决于 scope）。

## 版本兼容性

- Rubric version: `2026-03-30`
- 审计引擎与 ECC 1.10.0 兼容
- 新版本 ECC 可能增加检查项，评分标准可能调整
