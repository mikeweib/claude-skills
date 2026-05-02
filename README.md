# Claude Skills

Claude Code 技能集合仓库。每个技能是一个独立目录，可被 Claude Code 加载使用。

## 安装

```bash
# 克隆仓库
mkdir -p ~/.claude/skills
git clone git@github.com:mikeweib/claude-skills.git ~/.claude/skills/claude-skills
```

然后在 `~/.claude/settings.json` 中配置 skills 路径（如需要）。

## 可用技能

| 技能 | 说明 |
|------|------|
| [cpp-memory-safety](./cpp-memory-safety/SKILL.md) | C++ 内存安全审查：智能指针、所有权、数组边界、悬空指针、Rule of Five、并发 |

## 技能结构

```
<skill-name>/
├── SKILL.md              # 技能入口，frontmatter + 完整指令
└── references/            # 代码示例等参考资料
```

## 贡献

添加新技能时，参照现有技能的目录结构：

1. 创建 `skill-name/` 目录
2. 编写 `SKILL.md`（YAML frontmatter + 中文正文）
3. 可选添加 `references/` 参考资料

## License

MIT
