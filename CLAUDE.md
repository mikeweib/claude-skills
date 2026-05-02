# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 仓库概述

这是一个 Claude Code 技能集合仓库（skills monorepo）。每个技能是一个独立目录，可被 Claude Code 加载使用。仓库地址：`git@github.com:mikeweib/claude-skills.git`。

## 技能目录结构

每个技能遵循以下约定：

```
<skill-name>/
├── SKILL.md              # 技能入口，包含 frontmatter 和完整指令
└── references/            # 参考资料（可选）
    └── <reference>.md
```

**SKILL.md 要求：**
- 必须以 YAML frontmatter 开头，包含 `name` 和 `description` 字段
- `name` 与目录名一致，使用 kebab-case
- `description` 一句话描述触发条件和用途，用于自动匹配
- 正文包含：触发条件（When to Use）、审查/执行流程、检查清单、常见错误

**references/ 目录：**
- 存放代码示例、速查表等辅助材料
- 文件名使用 kebab-case
- 在 SKILL.md 中用相对路径引用

## 当前技能

| 技能 | 用途 |
|------|------|
| `cpp-memory-safety` | C++ 内存安全审查：智能指针选择、所有权配对、数组边界、悬空指针、Rule of Five、异常安全、并发 |

## 技能编写规范

- 正文语言：中文（目标用户为中文开发者）
- frontmatter 中的 `name`/`description` 使用英文（Claude Code 内部匹配用）
- 代码注释和示例中的标识符保持英文
- 技能应包含 **触发条件** 和 **不使用的情况** 两段，帮助 Claude Code 判断是否加载
- 审查类技能应提供分步流程，按优先级排列，每步有明确的输入/输出

## 开发环境

`~/.claude/skills/cpp-memory-safety` 是该仓库 `cpp-memory-safety/` 的软链接。在此仓库修改技能文件后，Claude Code 立即生效，无需复制。新增其他技能后，同样在 `~/.claude/skills/` 下创建对应的软链接。

```bash
ln -s /Users/leigod/Documents/workspace/github/claude-skills/<skill-name> ~/.claude/skills/<skill-name>
```

## Git 工作流

- 主分支：`main`
- 提交格式：`<type>: <description>`（feat, fix, refactor, docs 等）
- 所有由 Claude 发起的 commit 需添加 `Co-Authored-By` 行
