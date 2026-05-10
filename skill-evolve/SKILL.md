---
name: skill-evolve
description: Meta-skill for skill auto-evolution with eval gating and rollback. Use when the user says "skill 进化", "进化 <skill-name>", "evolve skill <name>", "skill 改进", "分析 skill 反馈", "improve skill <name>", "skill 回滚 <name>", "回滚 <skill-name>", "rollback skill <name>". Also auto-triggers when a skill accumulates >= 3 unprocessed feedback entries. Analyzes feedback from auto-memory, identifies improvement patterns, runs eval gating to prevent regressions, generates targeted diffs against SKILL.md, requires human approval before applying changes, records evolution history, and supports rollback to pre-evolution state.
---

# Skill 进化

## Overview

元技能——通过结构化反馈循环让技能自进化。它读取 auto-memory 中的反馈记录，分析问题模式，生成针对 SKILL.md 的改进建议，经人工确认后应用变更并记录进化历史。支持回滚到任意进化前的状态。

**目标用户：** Skill 维护者。

**已管理技能：** `prd-review`, `tech-debt-scanner`, `gn-reviewer`, `cpp-memory-safety`, `harness-score`（此仓库内所有自建 skill 均可管理，新 skill 按[接入指南](#new-skill-bootstrapping-新-skill-接入)接入即可）。

## When to Use 触发条件

### 进化触发

- "skill 进化"、"进化 <skill-name>"、"skill 改进"
- "分析 skill 反馈"、"evolve skill X"、"improve skill X"
- "<任意 skill 名> 有什么可以改进的"

**自动触发（无需用户主动要求）：**
- 当 auto-memory 中同一 skill 积累 >= 3 条未处理的反馈时，主动提示"检测到 X 条新反馈，是否运行 skill 进化？"
- 当用户纠正 skill 输出后被记录为 feedback 时，会话结束前主动提示

### 回滚触发

- "skill 回滚 <skill-name>"、"回滚 <skill-name>"
- "rollback skill <name>"、"撤销 <skill-name> 的进化"
- "skill 回滚 <skill-name> 到 <date>"
- "查看 <skill-name> 的回滚点"、"<skill-name> 有哪些可以回滚的版本"

**不使用的情况：**
- 单纯询问 skill 的用法（不是改进/回滚）
- 进化场景下没有反馈积累的首次运行（提示用户先收集反馈）
- 回滚场景下目标 skill 没有任何进化记录
- 新建 skill（使用 `skill-create` 技能）

## New Skill Bootstrapping 新 Skill 接入

任何已有 skill 零成本接入，3 级递进：**L1 基础**（zero-config）→ **L2 结构化反馈**（添加 `feedback-template.md`）→ **L3 完整进化**（添加 `eval/` 用例，启用评估门控）。当前 5 个 skill 均已达到 L3。

> **接入步骤和已接入 skill 状态：** 详见 `references/skill-evolve-guide.md` 快速开始章节。

---

## Evolution Workflow 进化流程

### Step 1: 收集反馈

从两个来源收集反馈，合并为反馈池：

**来源 A — auto-memory：**
1. 读取 auto-memory 索引文件：`~/.claude/projects/<project-hash>/memory/MEMORY.md`
2. 对索引中的每条，读取对应的 `.md` 文件
3. 筛选：`name` frontmatter 字段包含目标 skill 名称的条目

**来源 B — 对话输入：**
- 用户在本次对话中直接描述的 skill 问题
- 先尝试按 `<skill-name>/references/feedback-template.md` 的格式结构化
- 如果目标 skill 没有专用模板，使用通用模板 `skill-evolve/references/feedback-template.md`

**输出：** 反馈列表，每条包含：
- 来源（文件路径或对话）
- 问题类型（误判/漏判/格式问题/建议不实用）
- 涉及维度（如适用）
- 严重程度（高/中/低）
- 反馈摘要

> **边界情况：**
>
> | 场景 | 处理方式 |
> |------|---------|
> | 目标 skill 无 feedback 记录 | 提示"未找到 <skill-name> 的反馈记录"，建议用户先使用 skill 积累反馈 |
> | 反馈数 < 2 条 | 降低置信度标注，仅建议低风险改进（措辞/示例补充），不调整核心规则 |
> | 反馈数 >= 5 条 | 标注"高置信度"，可考虑系统性问题 |
> | 用户同时提供多个 feedback 来源 | 合并去重（按 originSessionId）|

### Step 2: 分析反馈模式

按问题类型分组：

| # | 类型 | 定义 | 识别信号 | 常见修复目标 |
|---|------|------|---------|------------|
| 1 | **terminology-calibration** | 术语适用范围需细化，不该扣却扣了 | "这个不应扣分，是行业通用术语" | review-checklist.md 术语检查项 |
| 2 | **threshold-adjustment** | 扣分值/权重/门槛等数值不合理 | 某维度得分反复集中在极低/极高区间 | 维度权重、最高扣分、及格线 |
| 3 | **checklist-update** | 检查清单遗漏或冗余 | 审查漏掉某类问题 / 检查项重复 | review-checklist.md 检查项 |
| 4 | **trigger-refinement** | 触发条件误判（该触发未触发/不该触发却触发了） | "我问了 X 但 skill 没激活" | SKILL.md frontmatter description / When to Use |
| 5 | **diagnostic-enhancement** | 边界场景处理不完善 | 维度 < 40% 但 diagnostic-guide.md 无对应建议 | diagnostic-guide.md / 边界表 |
| 6 | **example-addition** | 缺少示例导致判断不一致 | 同类文档两次评审差异大 | SKILL.md / reference 示例 |

> 完整定义和 prd-review 案例详见 `references/skill-evolve-guide.md` 6 种改进分类章节。

**分析输出——对每组反馈：**
- 根因：是 SKILL.md 哪个章节/段落的哪个规则导致的问题
- 影响范围：只影响一个维度还是多个
- 严重程度：**高**（评分失真或系统性误判）、**中**（一致性问题但非致命）、**低**（措辞/示例优化）
- 优先级排序：高 > 中 > 低；同等级按反馈数量排序

### Step 2.5: 分析结果确认（检查点）

在进入建议生成之前，**暂停并展示分析结果**，等待用户确认分析方向是否正确：

```
## 反馈分析结果（待确认）

### 反馈概览
| 来源 | 条数 | 时间范围 |
|------|------|---------|
| auto-memory | 3 | 2026-05-01 ~ 2026-05-10 |
| 对话输入 | 1 | 2026-05-10 |

### 按问题类型分组

| 类型 | 条数 | 严重度 | 涉及 skill 章节 | 典型反馈摘要 |
|------|------|--------|----------------|-------------|
| checklist-update | 2 | 高 | 维度 4 风险识别 | 缺少风控误伤预案检查 |
| terminology-calibration | 1 | 中 | 维度 2 清晰度 | 行业通用术语被误扣分 |
| example-addition | 1 | 低 | 维度 7 逻辑一致性 | 冲突矩阵缺少示例 |

### 优先级排序
1. **[高] checklist-update** — 2 条反馈指向同一问题，建议合并为一个建议
2. **[中] terminology-calibration** — 1 条反馈
3. **[低] example-addition** — 1 条反馈（不强制生成 diff）

是否按以上分组和优先级生成改进建议？
- "确认" / "OK" → 进入 Step 3 生成建议
- "类型 X 应该是 Y" → 调整分组
- "先只看高严重度" → 只对选定的严重度生成建议
- "忽略 #N" → 排除指定反馈组
```

**检查点的核心价值：** 在生成具体的 diff 之前纠正分析方向。分组错误会导致后续所有建议偏离，此时纠正成本最低。

**用户可能的回应：**
- "确认" → 进入 Step 3
- "类型 X 不对，应该是 Y" → 调整分组后重新展示
- "忽略低严重度，只看高的" → 过滤后进入 Step 3
- "反馈 #3 实际是误报，不要处理" → 移除该反馈组

> **跳过条件：** 如果只有 1 条反馈且问题类型明确，可跳过此检查点直接进入 Step 3。但需在分析输出中标注"单条反馈，跳过分析确认"。

### Step 3: 生成改进建议

为每个高/中严重度组生成变更建议（格式规范见 `references/skill-evolve-guide.md` Diff 呈现规范章节）。低严重度组列出但不强制生成 diff。

**建议排序规则：**
1. 高严重度优先
2. 同级别按涉及反馈数量排序
3. 涉及同一文件的建议合并呈现

**合并策略：** 多条反馈指向同一问题时合并为一个建议，提高优先级。

### Step 3.5: 评估门控（Eval Gating）

> 提交审批前，用 eval 用例验证变更不会导致退化。无 eval 用例则跳过。

**流程：** 读取 baseline → 预评估每个建议对 eval 用例的影响方向（↑/↓/→）→ 门控决策：

| 级别 | 条件 | 行为 |
|------|------|------|
| 🟢 passed | 全部用例预期不变或提升 | 正常进入审批 |
| 🟡 warning | 非核心用例可能下降 | 进入审批，标注风险 |
| 🔴 blocked | 核心用例（eval-001/002）预期下降 | 阻止自动审批，需用户显式覆盖 |
| ⚠️ no-eval | 目标 skill 无 eval 用例 | 跳过 |

> 门控详情（基线建立、影响推断规则、核心用例定义、用户覆盖后果）：详见 `references/skill-evolve-guide.md` 评估门控章节。

### Step 4: 确认并应用

展示改进建议汇总表 + 评估门控结果，等待用户确认：

```
## 改进建议汇总

| # | 类型 | 严重度 | 目标文件 | 标题 | Eval |
|---|------|--------|---------|------|------|
| 1 | terminology-calibration | 中 | review-checklist.md | 术语检查区分通用术语 vs 项目特有概念 | 🟢 passed |
| 2 | ... | | | | 🟡 warning |

**评估门控:** 🔴 blocked / 🟡 warning / 🟢 passed / ⚠️ 无 eval 用例

是否批准应用以上变更？

- "是" / "确认" / "全部应用" → 应用所有建议
- "应用 1" → 仅应用指定编号
- "修改 #1: [修改意见]" → 修改后重新呈现
- "否" / "拒绝" → 中止，此次分析结果丢弃
```

> **🔴 blocked 的额外要求：** 当评估门控为 blocked 时，用户必须显式回复"忽略 eval 警告，确认应用"才能执行。普通"是"不生效。

**批准后执行：**

0. **创建备份快照**（命名与存储规则见 `references/rollback-guide.md`）
1. 用 Edit 工具对目标文件逐一应用变更，每步验证完整性
2. 在 `skill-evolve/evolution-log/` 创建进化记录（格式见 `references/skill-evolve-guide.md` 进化记录格式章节）
3. 更新 `evolution-log/INDEX.md`

### Step 5: 回滚

> 当进化后的 skill 效果不佳、引入退化、或用户改变主意时，回滚到进化前的状态。

#### 5.1 列出可回滚点

**触发后第一步——展示回滚点列表：**

1. 扫描 `skill-evolve/evolution-log/<skill-name>/` 下所有进化记录
2. 筛选条件：状态为 `✅ 已应用` 且有备份快照的记录
3. 对每条可回滚记录，展示摘要信息：

```
## <skill-name> 可回滚的版本

| # | 日期 | 变更描述 | 影响文件 | 评估门控 |
|---|------|---------|---------|---------|
| 1 | 2026-05-10 | 术语检查区分通用术语 vs 项目特有概念 | prd-review/SKILL.md | ⚠️ 无 eval |
| 2 | 2026-05-08 | ... | ... | 🟢 passed |

输入编号选择要回滚的版本，或输入 "取消"。
```

**边界情况：** 详见 `references/rollback-guide.md` 回滚决策树（无记录/无备份/指定日期/堆叠进化等场景）。

#### 5.2 展示回滚影响

**用户选择回滚点后——展示回滚将做什么：**

1. 读取备份快照内容
2. 读取对应目标文件的当前内容
3. 用 diff 格式展示变更（备份 → 当前）：

```
## 回滚预览: 2026-05-10 术语检查校准

### 影响文件: prd-review/SKILL.md

--- 回滚前（当前内容）
[当前文件中的相关片段]
+++ 回滚后（恢复为进化前内容）
[备份中的对应片段]

**回滚后将撤销以下进化记录：**
- 2026-05-10: 术语检查校准

是否确认回滚？
- "是" / "确认回滚" → 执行回滚
- "取消" → 中止
```

#### 5.3 执行回滚

**用户确认后：**

1. 从备份目录读取每个目标文件的完整备份内容
2. 用 Write 工具将备份内容写回目标文件（覆盖当前内容）
3. 验证文件完整性（行数合理性检查、关键章节存在性检查）
4. 创建回滚记录：`skill-evolve/evolution-log/<skill-name>/YYYY-MM-DD-rollback-<slug>.md`

**回滚记录格式：** 详见 `references/rollback-guide.md` 回滚记录 vs 进化记录章节。

5. 更新原进化记录的状态为 `🔄 已回滚（于 YYYY-MM-DD）`
6. 更新 `evolution-log/INDEX.md`，添加回滚记录

#### 5.4 回滚后的反馈处理

回滚完成后，询问用户：

```
回滚已完成。原进化记录关联的反馈是否也需要处理？

- "重新分析" → 将原反馈标记为未处理，下次进化时重新评估
- "保留已处理" → 反馈状态不变
- "标记无效" → 将原反馈标记为无效（不再触发进化建议）
```

#### 5.5 回滚安全规则

5 条强制规则（不得跳过备份、不得静默覆盖、记录必须完整、可再次进化、备份不可删除），详见 `references/rollback-guide.md` 安全检查清单。

---

## 核心检查清单

### 进化流程
- [ ] 反馈来源已确认（至少 1 条结构化反馈或 memory 记录）
- [ ] 反馈已按问题类型分组
- [ ] Step 2.5 分析结果已获用户确认（分组/优先级/排除项）
- [ ] 每个改进建议有明确的反馈证据支撑
- [ ] 每个改进建议目标文件和位置明确
- [ ] 评估门控已完成（有 eval 用例则必须跑，无则标注跳过）
- [ ] 🔴 blocked 建议已获用户显式覆盖确认
- [ ] 变更已获用户批准，未跳过确认步骤
- [ ] 备份快照已创建（变更应用前）
- [ ] 进化记录已写入 `evolution-log/`（含备份路径）

### 回滚流程
- [ ] 回滚点列表已展示，用户已选择目标版本
- [ ] 备份快照存在且完整（已验证）
- [ ] 回滚 diff 预览已展示并获用户确认
- [ ] 回滚记录已写入 `evolution-log/`
- [ ] 原进化记录状态已更新为 `🔄 已回滚`
- [ ] 关联反馈状态已按用户选择处理

## Quick Reference 速查

### 进化速查
| 场景 | 动作 | 注意 |
|------|------|------|
| 仅有 memory/ 反馈 | 全部自动读取分析 | 过滤非目标 skill 的反馈 |
| 用户直接提供反馈 | 合并到反馈池 | 优先使用用户提供的最新反馈 |
| 无任何反馈 | 提示用户先收集反馈 | 不凭空生成建议 |
| 多个反馈指向同一问题 | 合并为一个改进建议 | 提高优先级 |
| 反馈相互矛盾 | 标注冲突 | 让用户裁决 |
| Step 2.5 分析结果确认 | 展示分组和优先级，等用户确认 | 在生成 diff 前纠正方向，成本最低 |
| 目标 skill 无专用 feedback-template | 使用通用模板 | `skill-evolve/references/feedback-template.md` |
| 目标 skill 无 eval 用例 | 跳过 Step 3.5 | 标注 "⚠️ 无 eval 用例" |
| 评估门控 🔴 blocked | 要求用户显式确认覆盖 | 普通"是"不生效 |
| 同一 skill 反馈 >= 3 条 | 主动提示进化 | 会话结束前或下次对话开始时触发 |

### 回滚速查
| 场景 | 动作 | 注意 |
|------|------|------|
| 查看可回滚版本 | 扫描 evolution-log 目录 | 过滤状态 ✅ 已应用且有备份的记录 |
| 回滚到指定版本 | 展示 diff → 确认 → 恢复 → 记录 | 备份存在是前提 |
| 回滚后原反馈 | 询问用户处理方式 | 可选重新分析/保留/标记无效 |
| 无备份的回滚 | 提示手动参考进化记录反向修改 | 不自动执行 |
| 堆叠进化回滚 | 警告影响范围，建议从最新开始 | 每次回滚一个版本 |
| 指定日期无匹配记录 | 列出最接近的日期 | 让用户确认 |

## Common Issues 常见问题

### 进化
| 问题 | 处理方式 |
|------|---------|
| 反馈数量太少（< 2 条）| 降低置信度，只生成低风险的措辞/示例改进 |
| 改进建议涉及多个文件 | 按依赖顺序排列，先改 SKILL.md 再改 references |
| eval 用例过时或覆盖不全 | 标注 `⚠️ eval 覆盖不完整`，降低门控拦截力度 |

### 回滚
| 问题 | 处理方式 |
|------|---------|
| 回滚点无备份快照 | 提示手动操作：参考进化记录中的变更详情反向修改 |
| 回滚后还想恢复 | 备份不删除，可对新回滚记录再次回滚（回滚的回滚 = 恢复） |
| 回滚前文件已被手动修改 | 提示当前文件与备份 diff 有额外差异，让用户确认是否仍要覆盖 |

> 完整常见问题列表：详见 `references/skill-evolve-guide.md` 和 `references/rollback-guide.md`。

## Evolution History 进化历史

进化记录存放在 `skill-evolve/evolution-log/<skill-name>/`，索引文件 `evolution-log/INDEX.md` 列出所有记录。

> 目录结构、进化记录格式、回滚记录格式：详见 `references/skill-evolve-guide.md` 进化记录格式章节和 `references/rollback-guide.md`。

## References 参考文件

- **[skill-evolve-guide.md](references/skill-evolve-guide.md)** — 反馈分析指南（6 类改进分类详解、反馈质量标准、diff 呈现规范、评估门控指南、自动触发配置）
- **[feedback-template.md](references/feedback-template.md)** — 通用反馈记录模板（目标 skill 有专用模板时优先使用专用模板）
- **[rollback-guide.md](references/rollback-guide.md)** — 回滚操作指南（备份结构、回滚决策树、回滚后反馈处理、安全检查清单）
- **[evolution-log/INDEX.md](evolution-log/INDEX.md)** — 所有 skill 的进化记录索引
