---
name: harness-score
description: Use when the user asks to score, grade, or audit a project's agent harness compliance — e.g. "给工程打分", "harness 评分", "检查 harness 配置", "这个项目 harness 合规吗". Runs deterministic harness-audit and translates the raw score into an interpreted grade (A–F) with per-category analysis, prioritized fix recommendations, and suggested ECC skills.
---

# Harness 工程评分

## Overview

对项目进行 agent harness 合规评分。基于 ECC (Everything Claude Code) harness 规范，通过确定性审计引擎给出 0–70 分的客观评分，并转换为 A–F 等级，同时提供改进建议。

## When to Use 触发条件

- 用户要求"给工程打分"、"harness 评分"、"检查 harness 合规"
- 用户想了解项目的 agent 基础设施完善程度
- 项目刚初始化，想知道还需要配置什么
- 定期审查 harness 配置是否退化

**不使用的情况：**
- 项目未安装 ECC 插件 —— 评分无意义
- 只是想运行 `/harness-audit` 看原始分数（直接运行命令即可）
- 在 ECC 仓库本身做开发（使用 `/harness-audit repo`）

## Scoring Workflow 评分流程

### Step 1: 环境预检

确认评分的前提条件：

1. **检查 ECC 插件安装**：查找 `~/.claude/plugins/cache/ecc/` 目录
2. **检查审计引擎可用**：确认 `scripts/harness-audit.js` 存在
3. **确定项目根目录**：默认为当前工作目录

**输出：** 环境是否就绪 / ECC 版本 / 审计引擎路径。

### Step 2: 运行确定性审计

执行审计引擎，获取原始评分数据：

```bash
node ~/.claude/plugins/cache/ecc/everything-claude-code/<version>/scripts/harness-audit.js --format json [--root <项目路径>]
```

审计引擎自动检测模式：
- **repo 模式**：目标本身是 ECC 插件仓库（满分 70）
- **consumer 模式**：普通项目使用 ECC（满分由实际检查项决定，通常 27–29 原始分）

**输出：** JSON 格式的完整审计报告。

### Step 3: 等级评定

将原始分数转换为等级：

| 得分率 | 等级 | 含义 | 行动 |
|--------|------|------|------|
| >= 90% | **A** | 优秀 — harness 配置完善 | 维护现状，关注 ECC 版本更新 |
| >= 70% | **B** | 良好 — 核心能力到位 | 补全少数缺失项 |
| >= 50% | **C** | 及格 — 基础能力存在 | 按优先级逐项补全 |
| >= 30% | **D** | 不及格 — 大量缺失 | 从 Tool Coverage 和 Quality Gates 开始 |
| < 30% | **F** | 严重不足 — 几乎无 harness | 先安装 ECC，再逐步配置 |

对于 **consumer 模式**，满分通常为 27–29 原始分（按类别归一化为 0–70），等级评定使用归一化后的得分率。

**输出：** 等级 + 总分 + 得分率。

### Step 4: 逐类分析

对 7 个类别逐一分析，给出具体建议：

#### 1. Tool Coverage（工具覆盖）— 权重最高

检查项（consumer 模式）：
- ECC 插件已安装
- 项目有 `.claude/` 下的本地覆盖（agents/skills/commands/settings）

**得分低的原因：**
- 未安装 ECC 插件 → 运行 `configure-ecc` skill
- `.claude/` 下无项目级配置 → 至少添加 `settings.json` 和 `CLAUDE.md`

#### 2. Context Efficiency（上下文效率）

检查项（consumer 模式）：
- 项目有 `CLAUDE.md` / `AGENTS.md` 指令文件
- 项目有 `.mcp.json` 或 `.claude/settings.json` 声明本地工具配置

**得分低的原因：**
- 缺少项目指令文件 → 创建 `CLAUDE.md` 描述项目技术栈和约定
- 缺少本地配置 → 添加 `.claude/settings.json`

#### 3. Quality Gates（质量门禁）

检查项（consumer 模式）：
- 项目有自动化测试入口（`npm test` / test 文件）
- 项目有 CI 工作流（`.github/workflows/`）

**得分低的原因：**
- 无测试脚本 → 在 `package.json` 添加 `test` 脚本
- 无 CI → 在 `.github/workflows/` 添加至少一个工作流

#### 4. Memory Persistence（记忆持久化）

检查项（consumer 模式）：
- 项目有持久化记忆（`.claude/memory.md` 或 `docs/adr/`）

**得分低的原因：**
- 无项目记忆 → 创建 `.claude/memory.md` 或 ADR 目录

#### 5. Eval Coverage（评估覆盖）

检查项（consumer 模式）：
- 项目有 eval 用例或多个自动化测试

**得分低的原因：**
- 测试文件不足 → 至少为核心流程添加 3 个测试
- 缺少 eval → 使用 `eval-harness` skill 建立回归评估

#### 6. Security Guardrails（安全护栏）

检查项（consumer 模式）：
- 有 `SECURITY.md` 或依赖扫描配置
- `.gitignore` 忽略 `.env` 等敏感文件
- 项目本地有 hook 护栏配置

**得分低的原因：**
- 无安全策略 → 添加 `SECURITY.md`
- `.gitignore` 未忽略 `.env` → 添加 `.env*` 到 `.gitignore`
- 无 hook 护栏 → 在 `.claude/settings.json` 中配置 PreToolUse hooks

#### 7. Cost Efficiency（成本效率）

consumer 模式下通常无直接检查项。建议：
- 使用 `cost-aware-llm-pipeline` skill
- 配置模型路由（`model-route` command）

**输出：** 每个类别的得分率 + 缺失项 + 针对性 fix 建议。

### Step 5: 改进路线图

按 ROI 排序生成行动计划：

1. **立即修复（高 ROI）**：分值高且易于修复的项
2. **短期改进（中 ROI）**：需要一定投入但有显著提升的项
3. **长期完善（低 ROI）**：锦上添花的项

**输出：** 带优先级的行动清单，每个行动关联具体的文件路径和 ECC skill。

### Step 6: 基线记录（可选）

如果用户希望跟踪改进：

- 保存评分结果为基线
- 下次评分时对比变化

## 核心检查清单

项目评分时对照此清单：

- [ ] ECC 插件已安装且可用
- [ ] 项目有 `CLAUDE.md` 或 `AGENTS.md`
- [ ] 项目有 `.claude/settings.json` 或 `.mcp.json`
- [ ] 项目有 `.claude/` 下的本地覆盖（agents/skills/commands 至少一种）
- [ ] 项目有自动化测试入口
- [ ] 项目有 CI 工作流
- [ ] 项目有持久化记忆机制
- [ ] 项目有安全策略文档
- [ ] `.gitignore` 包含 `.env` 等敏感文件
- [ ] 项目有 hook 护栏配置

## 评分等级速查

| 等级 | consumer 原始分阈值 | 说明 |
|------|-------------------|------|
| A | >= 26 / 29 | 7 个类别基本满分，仅少量边缘项缺失 |
| B | >= 20 / 29 | 核心类别到位（Tool Coverage + Quality Gates + Security） |
| C | >= 15 / 29 | ECC 已安装且有基础配置，但多个类别缺失 |
| D | >= 9 / 29 | ECC 可能已安装但项目级配置几乎为空 |
| F | < 9 / 29 | 未安装 ECC 或几乎无任何 harness 配置 |

## Suggested ECC Skills 推荐使用的 ECC 技能

根据评分缺口，推荐以下技能：

| 缺口类别 | 推荐技能 | 用途 |
|----------|---------|------|
| Tool Coverage | `configure-ecc` | 配置 ECC 插件和项目级覆盖 |
| Context Efficiency | `strategic-compact` | 优化上下文使用 |
| Quality Gates | `quality-gate` | 建立质量门禁 |
| Memory Persistence | `continuous-learning-v2` | 记忆持久化和演进 |
| Eval Coverage | `eval-harness` | 建立评估框架 |
| Security Guardrails | `security-review` | 安全审查 |
| Cost Efficiency | `cost-aware-llm-pipeline` | 成本感知的路由策略 |
| 全局优化 | `harness-optimizer` agent | 自动分析并优化 harness 配置 |

## Common Issues 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 评分为 0 或接近 0 | ECC 未安装 | 安装 ECC 插件 |
| Tool Coverage 得分低 | 无项目级 `.claude/` 配置 | 至少创建 `CLAUDE.md` 和 `settings.json` |
| 所有类别都是 0 | 审计引擎未找到 consumer 模式标志 | 确认项目有 `.claude/` 或 `AGENTS.md` |
| Quality Gates 得分低 | 无测试/CI | 添加 `npm test` 和 GitHub Actions |
| Security 得分低 | 缺少安全文档和护栏 | 添加 `SECURITY.md`、更新 `.gitignore`、配置 hooks |
| Cost Efficiency 显示 N/A | consumer 模式无此检查项 | 正常现象，可手动使用 `cost-aware-llm-pipeline` skill |

## References 参考文件

- **[scoring-details.md](references/scoring-details.md)** — 7 类检查项的详细评分标准和权重说明
