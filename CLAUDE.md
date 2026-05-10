# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库概述

这是一个 Claude Code 技能集合仓库（skills monorepo）。每个技能是一个独立目录，可被 Claude Code 加载使用。仓库地址：`git@github.com:mikeweib/claude-skills.git`。

## 技能目录结构

每个技能遵循以下约定：

```
<skill-name>/
├── SKILL.md              # 技能入口，包含 frontmatter 和完整指令
├── scripts/               # 自动化脚本（可选）
│   └── <script>.sh        #   shell 脚本，输出 file:line 格式
├── references/            # 参考资料（可选）
│   └── <reference>.md
└── eval/                  # 评估用例（可选，用于 skill-evolve 评估门控）
    ├── eval-cases.json    #   评估用例定义
    └── baseline.json      #   基线分数追踪
```

**SKILL.md 要求：**
- 必须以 YAML frontmatter 开头，包含 `name` 和 `description` 字段
- `name` 与目录名一致，使用 kebab-case
- `description` 一句话描述触发条件和用途，用于自动匹配
- 正文包含：触发条件（When to Use）、审查/执行流程、检查清单、常见错误

**scripts/ 目录：**
- 存放辅助审查的 shell 脚本，输出格式统一为 `file:line` 便于导航
- 脚本在 SKILL.md 的对应 Step 中通过 `**自动化：**` 标记引用
- 脚本应处理边界情况（无匹配文件、缺参数等），优雅退出
- 文件名使用 kebab-case

**references/ 目录：**
- 存放代码示例、速查表等辅助材料
- 文件名使用 kebab-case
- 在 SKILL.md 中用相对路径引用

## 当前技能

| 技能 | 用途 |
|------|------|
| `cpp-memory-safety` | C++ 内存安全审查：智能指针选择、所有权配对、数组边界、悬空指针、Rule of Five、异常安全、并发 |
| `harness-score` | Harness 工程评分：基于 ECC 规范对项目 agent harness 合规性打分（A-F 等级），逐类分析并给出改进建议 |
| `gn-reviewer` | GN 构建文件审查：检查 BUILD.gn / .gni 的 import 路径、依赖声明、target 类型、config 作用域、visibility、testonly、WebRTC 模板使用 |
| `tech-debt-scanner` | 技术债扫描：多语言标记注释/死代码/复杂度/废弃 API/重复代码五维度扫描，量化评分（A-F 等级） |
| `prd-review` | 需求评审：对 PRD 和原型图进行 7 维度综合评审（完整性/清晰度/可行性/风险识别/可测试性/UX 一致性/逻辑一致性），输出 0-100 分和 A-F 等级，及格线 60 分 |
| `skill-evolve` | Skill 进化元技能：读取 auto-memory 反馈，分析问题模式，生成改进建议，经人工确认后自动修改 skill 文件并记录进化历史 |

## 技能编写规范

- 正文语言：中文（目标用户为中文开发者）
- frontmatter 中的 `name`/`description` 使用英文（Claude Code 内部匹配用）
- 代码注释和示例中的标识符保持英文
- 技能应包含 **触发条件** 和 **不使用的情况** 两段，帮助 Claude Code 判断是否加载
- 审查类技能应提供分步流程，按优先级排列，每步有明确的输入/输出
- 如有关联脚本，在 SKILL.md 中添加 `## Scripts` 速查表，并在对应 Step 中通过 `**自动化：**` 引用

**eval/ 目录：**
- 存放评估用例（eval-cases.json）和基线分数（baseline.json），供 `skill-evolve` 评估门控使用
- eval-cases.json: 描述各场景的输入、预期行为和分数区间
- baseline.json: 跟踪上次验证的分数，变更后可对比是否退化
- 审查/评分类 skill 建议至少包含 2 个用例（正常场景 + 异常场景）

## Skill 进化

`skill-evolve` 元技能管理所有自建 skill 的进化：

```
skill 进化 <skill-name>
```

进化流程：收集反馈 → 分析模式 → 评估门控 → 生成改进建议 → 人工审批 → 应用变更。所有 skill 当前处于 L3 完整进化级别（含反馈模板 + eval 用例）。

## 开发环境

技能软链接配置（共 6 个）：

```bash
ln -s /Users/leigod/Documents/workspace/github/claude-skills/cpp-memory-safety ~/.claude/skills/cpp-memory-safety
ln -s /Users/leigod/Documents/workspace/github/claude-skills/gn-reviewer ~/.claude/skills/gn-reviewer
ln -s /Users/leigod/Documents/workspace/github/claude-skills/harness-score ~/.claude/skills/harness-score
ln -s /Users/leigod/Documents/workspace/github/claude-skills/tech-debt-scanner ~/.claude/skills/tech-debt-scanner
ln -s /Users/leigod/Documents/workspace/github/claude-skills/prd-review ~/.claude/skills/prd-review
ln -s /Users/leigod/Documents/workspace/github/claude-skills/skill-evolve ~/.claude/skills/skill-evolve
```

在此仓库修改技能文件后，Claude Code 立即生效，无需复制。

## Git 工作流

- 主分支：`main`
- 提交格式：`<type>: <description>`（feat, fix, refactor, docs 等）
- 所有由 Claude 发起的 commit 需添加 `Co-Authored-By` 行
