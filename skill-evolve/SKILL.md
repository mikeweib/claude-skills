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

任何已有 skill 都可以零成本接入 skill-evolve 管理。要获得完整进化能力（含评估门控），需要补充 3 个可选文件：

```
<skill-name>/
├── references/
│   └── feedback-template.md    # 可选：skill 专用的反馈模板（有针对性的字段）
└── eval/
    ├── eval-cases.json          # 可选：评估用例（用于回归检测）
    └── baseline.json            # 可选：基线分数
```

### 接入级别

| 级别 | 需要的文件 | 获得的能力 |
|------|-----------|-----------|
| **L1 基础** | 无（zero-config） | 反馈收集 + 模式分析 + 改进建议 + 人工审批 |
| **L2 结构化反馈** | `references/feedback-template.md` | 上述 + 反馈自动结构化解析 |
| **L3 完整进化** | L2 + `eval/eval-cases.json` + `eval/baseline.json` | 上述 + 评估门控（变更前自动检测退化风险） |

### 快速接入步骤

**Step 1（L1 — 零配置接入）：**
skill-evolve 自动发现 auto-memory 中匹配的 feedback，无需任何配置。
```
skill 进化 <skill-name>
```

**Step 2（L2 — 添加专用反馈模板）：**
从 `skill-evolve/references/feedback-template.md` 复制通用模板到 skill 目录，按 skill 领域定制字段。
```
cp skill-evolve/references/feedback-template.md <skill-name>/references/
# 编辑模板，将"涉及维度"改为 skill 特有的评估维度
```

**Step 3（L3 — 添加 eval 用例）：**
参考 `prd-review/eval/eval-cases.json` 的格式，为 skill 创建边界场景用例。
```
mkdir -p <skill-name>/eval
cp prd-review/eval/baseline.json <skill-name>/eval/
# 编辑 eval-cases.json，描述每个用例的输入和预期行为
```

> **1 个 eval 用例即可见效**：不需要像 prd-review 那样 7 个用例。即使只有 1 个用例覆盖核心场景，评估门控就能标记该场景的退化风险。

### 已接入 skill 状态

| Skill | 接入级别 | feedback-template | eval 用例 |
|-------|---------|-------------------|----------|
| prd-review | L3 完整进化 | ✅ 专用模板 | ✅ 7 个用例 |
| tech-debt-scanner | L3 完整进化 | ✅ 专用模板 | ✅ 5 个用例 |
| gn-reviewer | L3 完整进化 | ✅ 专用模板 | ✅ 5 个用例 |
| cpp-memory-safety | L3 完整进化 | ✅ 专用模板 | ✅ 5 个用例 |
| harness-score | L3 完整进化 | ✅ 专用模板 | ✅ 4 个用例 |

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

按问题类型分组。分类体系详见 `references/skill-evolve-guide.md`：

| 类型 | 说明 | 典型信号 |
|------|------|---------|
| **terminology-calibration** | 术语/概念适用范围校准 | 某个检查项对不该扣分的内容扣了分 |
| **threshold-adjustment** | 阈值/边界调整 | 扣分值、权重、得分率门槛不合理 |
| **checklist-update** | 检查清单增删 | 漏检或检查项过时 |
| **trigger-refinement** | 触发条件细化 | 该触发却未触发，或不该触发却触发了 |
| **diagnostic-enhancement** | 边界/诊断规则增强 | 边界场景处理不当，诊断指南缺少内容 |
| **example-addition** | 示例补充 | 缺少具体示例导致判断不一致 |

**分析输出——对每组反馈：**
- 根因：是 SKILL.md 哪个章节/段落的哪个规则导致的问题
- 影响范围：只影响一个维度还是多个
- 严重程度：**高**（评分失真或系统性误判）、**中**（一致性问题但非致命）、**低**（措辞/示例优化）
- 优先级排序：高 > 中 > 低；同等级按反馈数量排序

### Step 3: 生成改进建议

为每个高/中严重度组生成变更建议。低严重度组列出但不强制生成 diff。

**每个建议的格式：**

```
### 建议 #N: [简短标题]

- **问题类型:** [类型]
- **关联反馈:** [反馈文件/会话 ID]
- **严重程度:** [高/中/低]
- **目标文件:** [路径]
- **目标位置:** [章节/行号]

**变更内容:**
--- 原内容
[当前 SKILL.md 或 reference 中的原文]
+++ 新内容
[建议修改后的内容]

**理由:** [1-2 句话说明为什么这样改]
```

**建议排序规则：**
1. 高严重度优先
2. 同级别按涉及反馈数量排序
3. 涉及同一文件的建议合并呈现

**合并策略：** 多条反馈指向同一问题时合并为一个建议，提高优先级。

### Step 3.5: 评估门控（Eval Gating）

> 在提交变更给用户审批前，用 eval 用例验证变更不会导致退化。此步骤受 Hermes Agent 的约束门控机制启发——"改完后跑测试，分数下降就拒绝"。

**前提检查：**
1. 检查目标 skill 是否存在 `eval/eval-cases.json` 和 `eval/baseline.json`
2. 如果不存在 → 跳过此步骤，标注 `⚠️ 该 skill 暂无 eval 用例，跳过自动评估`
3. 如果存在 → 执行以下评估流程

**评估流程：**

1. **建立基线（pre-change baseline）：**
   - 读取 `baseline.json` 中已有的历史分数作为参考基线
   - 如果 baseline 为空，说明当前 skill 版本未经 eval 验证——标注 `ℹ️ 无历史基线，将当前变更后的首次评估结果作为新基线`

2. **预评估变更影响（pre-check）：**
   - 对每个改进建议，判断它可能影响哪些 eval 用例的哪些维度
   - 列出受影响的 eval 用例和维度，标注预期影响方向（↑ 提升 / ↓ 可能下降 / → 无影响）

3. **生成评估报告：**
   ```
   ## 评估门控报告
   
   | Eval 用例 | 受影响维度 | 预期影响 | 基线分数 | 风险 |
   |-----------|-----------|---------|---------|------|
   | eval-001 | 清晰度 | ↑ 提升 | 14/18 | 🟢 低 |
   | eval-003 | 清晰度 | ↓ 可能下降 | 5/9 | 🟡 中 |
   
   **整体风险评估：**
   - 🟢 低风险：全部用例预期不变或提升
   - 🟡 中风险：有用例可能下降，但核心用例（eval-001/002）无影响
   - 🔴 高风险：核心用例预期下降
   ```

4. **门控决策：**
   - 🟢 → 正常进入 Step 4（标记 "eval: passed"）
   - 🟡 → 进入 Step 4 但标注风险警告（标记 "eval: warning"），提醒用户关注特定维度
   - 🔴 → 进入 Step 4 但强制标注 "eval: blocked"，要求用户显式确认覆盖

> **Hermes 对比：** Hermes 用 GEPA 遗传算法自动跑分 + 约束门控自动拦截。skill-evolve 目前用 LLM 做预评估（基于改进建议的性质推断影响方向），因为 eval 用例通常没有预设的测试数据可以自动化运行。当 eval 用例配有具体测试 PRD 文件后，可以升级为实际跑分验证。

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

0. **创建备份快照（回滚点）：**
   - 在 `skill-evolve/evolution-log/<skill-name>/backups/<YYYY-MM-DD-<slug>>/` 创建备份目录
   - 对每个即将修改的目标文件，用 Read 读取完整内容，保存为备份文件
   - 备份文件命名：将目标文件的相对路径中的 `/` 替换为 `_`（如 `prd-review_SKILL.md`）
   - 在进化记录中标注备份路径

1. 用 Edit 工具对目标文件逐一应用变更
2. 每应用一个变更后验证文件完整性
3. 全部应用后在 `skill-evolve/evolution-log/` 创建进化记录（含备份路径和变更详情）
4. 更新 `evolution-log/INDEX.md`

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

**边界情况：**

| 场景 | 处理方式 |
|------|---------|
| 无进化记录 | 提示"<skill-name> 暂无进化记录，无需回滚" |
| 有记录但无备份 | 提示"记录 #N 无备份快照，无法自动回滚。可手动参考进化记录中的变更详情反向修改" |
| 指定日期无记录 | 提示最接近的日期记录，让用户确认 |
| 多个记录（堆叠进化） | 警告"回滚将撤销此记录之后所有堆叠的变更"，建议从最新记录开始逐个回滚 |

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

**回滚记录格式：**
```markdown
# 回滚记录: [原进化记录标题]

- **日期:** YYYY-MM-DD HH:MM
- **回滚目标:** [原进化记录文件名]
- **原进化日期:** YYYY-MM-DD
- **回滚原因:** [用户提供的原因，或 "用户主动回滚"]
- **恢复自备份:** [备份路径]
- **影响文件:** [路径列表]
- **状态:** 🔄 已回滚

## 原进化记录

- 原进化摘要: [从原记录复制的变更描述]
- 原触发反馈: [从原记录复制]

## 回滚详情

[从备份恢复了哪些文件]

## 用户决策
- 决策: 确认回滚
- 附加说明: [如有]
```

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

| 规则 | 说明 |
|------|------|
| **不得跳过备份** | 每次回滚前必须确认备份存在且完整 |
| **不得静默覆盖** | 回滚前必须展示 diff 预览并获用户确认 |
| **记录必须完整** | 回滚操作必须生成完整的回滚记录 |
| **可再次进化** | 回滚后的反馈如标记为"重新分析"，可在下次进化中重新处理 |
| **备份不可删除** | 即使回滚完成，原备份快照保留不删，支持再次回滚 |

---

## 核心检查清单

### 进化流程
- [ ] 反馈来源已确认（至少 1 条结构化反馈或 memory 记录）
- [ ] 反馈已按问题类型分组
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

### 进化常见问题
| 问题 | 处理方式 |
|------|---------|
| 反馈数量太少（< 2 条）| 降低置信度，只生成低风险的措辞/示例改进 |
| 反馈没有明确指出 SKILL.md 的问题 | 先反推可能的关联章节，标注 `[推测]` |
| 改进建议涉及多个文件 | 按依赖顺序排列，先改 SKILL.md 再改 references |
| 同一 skill 有多个版本的 feedback | 优先使用最新的反馈（按日期比较）|
| 某个改进建议用户反复拒绝 | 记录到进化日志 state=rejected，后续不再自动建议 |
| eval 用例过时或覆盖不全 | 标注 `⚠️ eval 覆盖不完整`，降低门控拦截力度 |
| 用户覆盖 🔴 blocked 后出现退化 | 在 evolution-log 记录退化情况，下次进化时优先关注 |

### 回滚常见问题
| 问题 | 处理方式 |
|------|---------|
| 回滚点无备份快照 | 提示手动操作：参考进化记录中的变更详情反向修改 |
| 回滚后还想恢复 | 备份不删除，可对新回滚记录再次回滚（回滚的回滚 = 恢复） |
| 回滚前文件已被手动修改 | 提示当前文件内容与备份 diff 有额外差异，让用户确认是否仍要覆盖 |
| 用户选择回滚多个版本 | 按时间倒序逐个回滚，每步确认 |
| 回滚后发现原进化其实更好 | 对回滚记录再执行回滚即可恢复 |

## Evolution History 进化历史

每个 skill 的进化记录存放在 `skill-evolve/evolution-log/<skill-name>/` 目录下。

**目录结构：**
```
evolution-log/<skill-name>/
├── YYYY-MM-DD-<slug>.md          # 进化记录
├── YYYY-MM-DD-rollback-<slug>.md # 回滚记录
└── backups/
    └── YYYY-MM-DD-<slug>/         # 备份快照（进化前的文件原文）
        ├── <skill>_SKILL.md
        └── <skill>_references_<file>.md
```

**进化记录格式：**
```markdown
# 进化记录: [简短描述]

- **日期:** YYYY-MM-DD HH:MM
- **触发反馈:** [反馈来源]
- **问题类型:** [类型]
- **变更描述:** [1 句话]
- **影响文件:** [路径列表]
- **备份路径:** [backups/ 下的目录路径]
- **评估门控:** 🟢 passed / 🟡 warning / 🔴 blocked / ⚠️ 无 eval 用例
- **状态:** ✅ 已应用 / ❌ 已拒绝 / 🔄 已回滚（于 YYYY-MM-DD）
```

**索引：** `skill-evolve/evolution-log/INDEX.md` 列出所有记录。

## References 参考文件

- **[skill-evolve-guide.md](references/skill-evolve-guide.md)** — 反馈分析指南（6 类改进分类详解、反馈质量标准、diff 呈现规范、评估门控指南、自动触发配置）
- **[feedback-template.md](references/feedback-template.md)** — 通用反馈记录模板（目标 skill 有专用模板时优先使用专用模板）
- **[rollback-guide.md](references/rollback-guide.md)** — 回滚操作指南（备份结构、回滚决策树、回滚后反馈处理、安全检查清单）
- **[evolution-log/INDEX.md](evolution-log/INDEX.md)** — 所有 skill 的进化记录索引
