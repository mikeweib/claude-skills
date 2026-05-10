# Claude Skills

Claude Code 技能集合仓库。每个技能是一个独立目录，可被 Claude Code 加载使用。

## 安装

```bash
# 克隆仓库
mkdir -p ~/.claude/skills
git clone git@github.com:mikeweib/claude-skills.git ~/.claude/skills/claude-skills
```

然后创建软链接到 `~/.claude/skills/`：

```bash
ln -s $(pwd)/<skill-name> ~/.claude/skills/<skill-name>
```

## 可用技能

| 技能 | 说明 |
|------|------|
| [cpp-memory-safety](./cpp-memory-safety/SKILL.md) | C++ 内存安全审查：智能指针、所有权、数组边界、悬空指针、Rule of Five、异常安全、并发 |
| [gn-reviewer](./gn-reviewer/SKILL.md) | GN 构建文件审查：import 路径、依赖声明、target 类型、config 作用域、visibility、testonly、WebRTC 模板 |
| [harness-score](./harness-score/SKILL.md) | Harness 工程评分：基于 ECC 规范对项目 agent harness 合规性打分（A-F 等级），逐类分析并给出改进建议 |
| [tech-debt-scanner](./tech-debt-scanner/SKILL.md) | 技术债扫描：多语言标记注释/死代码/复杂度/废弃 API/重复代码五维度扫描，量化评分（A-F 等级），输出逐类详细报告 |
| [prd-review](./prd-review/SKILL.md) | 需求评审：对 PRD 和原型图进行 7 维度综合评审（完整性/清晰度/可行性/风险识别/可测试性/UX 一致性/逻辑一致性），输出 0-100 分和 A-F 等级，及格线 60 分 |
| [skill-evolve](./skill-evolve/SKILL.md) | Skill 进化元技能：读取 auto-memory 反馈，分析问题模式，评估门控防退化，经人工确认后自动修改 skill 文件并记录进化历史 |

## 技能结构

```
<skill-name>/
├── SKILL.md              # 技能入口，frontmatter + 完整指令
├── scripts/               # 自动化检测脚本（可选）
│   └── *.sh               #   shell 脚本，输出 file:line 格式
├── references/            # 参考资料（可选）
│   └── *.md               #   代码示例、速查表、约定说明
└── eval/                  # 评估用例（可选，用于 skill-evolve 评估门控）
    ├── eval-cases.json    #   评估用例定义
    └── baseline.json      #   基线分数追踪
```

## 自动化脚本

每个技能可附带 `scripts/` 目录，存放辅助审查的 shell 脚本。脚本由 SKILL.md 在审查流程中引用，Claude Code 可直接调用获取结构化结果。

### cpp-memory-safety

| 脚本 | 用途 |
|------|------|
| `scan-raw-memory.sh [dir]` | 扫描 `new`/`delete`/`malloc`/`free` |
| `find-shared-ptr-overuse.sh [dir] [--webrtc]` | 统计 `shared_ptr` 使用 |
| `check-rule-of-five.sh [dir]` | 检查 raw pointer class 的 Rule of Five |

### gn-reviewer

| 脚本 | 用途 |
|------|------|
| `validate-imports.sh [dir\|file]` | 验证 `import()` 路径存在性 |
| `check-deps-headers.sh <BUILD.gn> <target>` | 交叉验证 header 与 deps 声明 |
| `check-testonly-leak.sh [dir]` | 检查 testonly 泄漏 |
| `find-duplicate-configs.sh [dir]` | 查找重复的 cflags/ldflags/defines |
| `find-dead-gn-code.sh [dir] [--threshold N]` | 查找大段注释代码 |

### tech-debt-scanner

| 脚本 | 用途 |
|------|------|
| `preflight-check.sh [dir]` | 环境预检：语言检测、文件统计 |
| `scan-marker-comments.sh [dir]` | 扫描 TODO/FIXME/HACK/XXX 等标记注释 |
| `scan-dead-code.sh [dir] [--threshold N]` | 检测注释代码块、空 catch、死条件 |
| `scan-complexity.sh [dir]` | 分析文件/函数大小、嵌套深度、参数数量 |
| `scan-deprecated-api.sh [dir]` | 扫描 @deprecated 注解和已知废弃 API |
| `scan-duplicate-code.sh [dir]` | 检测完全重复文件、复制粘贴块、高相似度文件 |

### harness-score

| 脚本 | 用途 |
|------|------|
| `preflight-check.sh [project_dir]` | 评分前环境预检 |

## Skill 进化

`skill-evolve` 是一个元技能，通过结构化反馈循环让所有技能自进化：

```
skill 进化 <skill-name>
```

**进化流程：** 收集反馈 → 分析模式 → 评估门控（防退化）→ 生成改进建议 → 人工审批 → 应用变更并记录进化历史。

**接入级别：** 所有 5 个技能均已达到 L3 完整进化级别（含专用反馈模板 + eval 用例）。

## Eval 系统

每个技能可附带 `eval/` 目录，包含：

- **eval-cases.json** — 定义评估用例：描述输入场景、预期行为、分数区间
- **baseline.json** — 跟踪上次验证的基线分数

skill-evolve 在应用变更前，会运行评估门控——用 eval 用例预评估变更影响，检测退化风险。

## 贡献

添加新技能时，参照现有技能的目录结构：

1. 创建 `skill-name/` 目录
2. 编写 `SKILL.md`（YAML frontmatter + 中文正文）
3. 可选添加 `scripts/` 自动化脚本（遵循 file:line 输出格式）
4. 可选添加 `references/` 参考资料
5. 可选添加 `eval/` 评估用例（接入 skill-evolve 评估门控）

## License

MIT
