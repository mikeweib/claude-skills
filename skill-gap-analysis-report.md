# Claude Code Skill/Agent 缺口分析报告

> 调研日期：2026-05-10
> 调研范围：仓库自建 skill（6个）+ ECC 系统 agent（48个）+ 系统 skill（~183个）+ 4个外部插件
> 分析维度：软件工程全流程 + 编程提效技巧

---

## 一、现有能力全景

### 1.1 仓库自建 Skill（6个）

| Skill | 领域 | 核心能力 |
|-------|------|---------|
| `cpp-memory-safety` | C++ 代码审查 | 智能指针选择、所有权配对、数组边界、Rule of Five、异常安全、并发 |
| `gn-reviewer` | 构建系统审查 | GN 文件的 import 路径、依赖声明、target 类型、config 作用域、visibility、WebRTC 约定 |
| `tech-debt-scanner` | 技术债量化 | 多语言 5 维度扫描（标记注释/死代码/复杂度/废弃 API/重复代码），0-100 评分 + A-F 等级 |
| `harness-score` | 工程平台审计 | 7 维度 ECC harness 合规性评分（工具覆盖/上下文效率/质量门/记忆持久化/评估/安全/成本） |
| `prd-review` | 需求评审 | 7 维度 PRD 评审（完整性/清晰度/可行性/风险/可测试性/UX 一致性/逻辑一致性），0-100 评分 |
| `skill-evolve` | 元技能 | 读取 auto-memory 反馈，分析模式，生成改进建议，评估门控，回滚支持 |

### 1.2 系统 Agent（48个）

| 领域 | 数量 | 覆盖情况 |
|------|------|---------|
| 规划与设计 | 5 | planner, architect, code-architect, code-explorer, type-design-analyzer |
| 代码实现 | 5 | tdd-guide, code-improvement-advisor, code-simplifier, silent-failure-hunter, comment-analyzer |
| 代码审查（通用） | 1 | code-reviewer |
| 代码审查（语言专项） | 10 | TypeScript, Python, Java, C++, Go, Rust, Kotlin, C#, Flutter, Database |
| 安全 | 2 | security-reviewer, healthcare-reviewer |
| 构建修复 | 9 | TypeScript, C++, Java, Go, Rust, Kotlin, Dart, PyTorch |
| 测试 | 2 | e2e-runner, pr-test-analyzer |
| 调试/运维 | 3 | loop-operator, harness-optimizer, conversation-analyzer |
| 文档 | 2 | doc-updater, docs-lookup |
| 重构 | 1 | refactor-cleaner |
| 性能 | 1 | performance-optimizer |
| 领域专项 | 4 | seo-specialist, a11y-architect, healthcare-reviewer, chief-of-staff |
| 开源流水线 | 3 | opensource-forker, opensource-sanitizer, opensource-packager |
| GAN 流水线 | 3 | gan-planner, gan-generator, gan-evaluator |

### 1.3 系统 Skill（~183个 + 插件）

- **Superpowers 插件（14个）：** brainstorming, writing-plans, executing-plans, systematic-debugging, subagent-driven-development 等开发流程 skill
- **Planning-with-Files 插件（12个）：** 多语言规划文件工作流
- **UI-UX-Pro-Max 插件（1个）：** UI/UX 设计与实现
- **Example Skills 插件（17个）：** Anthropic 官方示例（MCP builder, webapp-testing, skill-creator 等）
- **ECC 本地 skill（~183个）：** 覆盖各语言 patterns、测试、安全、框架、领域业务等多个维度

---

## 二、按软件工程流程维度的覆盖评估

| 流程阶段 | 覆盖等级 | 现状 | 关键缺失 |
|---------|---------|------|---------|
| 需求与分析 | ★★★★☆ 良好 | prd-review skill 覆盖 | 用户故事拆分、验收标准自动化验证 |
| 设计与架构 | ★★★★☆ 良好 | architect/planner agent + api-design skill | ADR 自动生成与强制执行 |
| 编码实现 | ★★★★★ 优秀 | 语言专项 agent + patterns skill | 无明显缺口 |
| 代码审查 | ★★★★★ 优秀 | 11 个 reviewer agent + 6 个审查 skill | 无明显缺口 |
| 测试 | ★★★★☆ 良好 | tdd-guide + e2e-runner + 14 个测试 skill | 模糊测试、无障碍测试 |
| 构建与 CI/CD | ★★★★☆ 良好 | 9 个 build-resolver agent | 依赖供应链安全检查 |
| **部署与运维** | **★★☆☆☆ 薄弱** | 仅有 deployment-patterns/docker-patterns skill | **无部署/回滚/灰度/事件响应 agent** |
| 文档 | ★★★☆☆ 一般 | doc-updater + update-release-notes | Changelog 自动生成、文档与代码一致性 |
| 项目管理 | ★★☆☆☆ 薄弱 | Jira skill | 迭代规划、估算、燃尽图分析 |
| 沟通协作 | ★★☆☆☆ 薄弱 | brand-voice, crosspost | **提交信息/PR 描述自动生成** |

---

## 三、缺口分析（按优先级）

### P0 — 关键缺失（日常高频使用，当前完全空白）

#### 1. Commit Message / PR 描述自动生成

- **当前状态：** 完全依赖 Claude 每次手动编写，无专用 agent/skill
- **为什么是 P0：** 每次提交都需要的操作，一致性难以保证；AI 提效场景下 PR 数量快速增长，手动编写成为瓶颈
- **建议实现方式：** Agent（非 Skill），因为需要 diff 分析 + 上下文理解
- **预期输入：** `git diff` 输出或当前分支变更
- **预期输出：** 符合 conventional commits 格式的提交信息 + 结构化 PR 描述（Summary / Changes / Test Plan）

#### 2. 依赖供应链安全审计

- **当前状态：** `security-reviewer` 只做源码级 OWASP 检查，`npm audit` 类工具未整合
- **为什么是 P0：** 供应链攻击已是头号安全威胁，缺乏自动化审计意味着盲飞
- **建议实现方式：** Skill + 脚本（扫描 CVE、许可证合规、typosquatting、dependency confusion）
- **覆盖范围：** npm/PyPI/Cargo/Maven 等多生态

#### 3. 数据库 Migration 与 Schema 演进

- **当前状态：** `database-reviewer` 审查查询和 schema 设计，`database-migrations` skill 只提供模式参考
- **为什么是 P0：** 数据库迁移是生产环境最高风险操作，需要向前+回滚计划、影响面分析
- **建议实现方式：** Agent（需要理解 ORM migration 文件 + 分析查询影响面）
- **预期能力：** 迁移安全性审查、回滚方案生成、零停机迁移策略、数据转换验证

#### 4. 部署与运维 Agent

- **当前状态：** 有 `deployment-patterns` / `docker-patterns` skill，但无操作级 agent
- **为什么是 P0：** 这是覆盖度最低的维度，生产事件响应完全依赖人工
- **建议实现方式：** Agent（需要理解部署流程、灰度策略、回滚决策）
- **预期能力：** 部署 checklist 生成、金丝雀/蓝绿策略建议、回滚方案、Kubernetes manifest 审查

---

### P1 — 高优先级（对质量/效率有明显提升）

#### 5. Changelog / Release Notes 自动生成

- **当前状态：** `update-release-notes` skill 存在但功能简单
- **建议实现方式：** Skill，读取两次 tag 之间的 commit 历史，按类型分类，识别 breaking changes，关联 issue/PR
- **预期输出：** 可直接发布的 Release Notes（Keep a Changelog 格式）

#### 6. API 契约与集成测试

- **当前状态：** `api-design` skill 覆盖设计模式，无契约验证
- **建议实现方式：** Skill + 脚本（OpenAPI/Swagger 规范验证、接口一致性对比、breaking change 检测）
- **预期能力：** API 文档与实际实现对比、消费者驱动契约测试建议、版本兼容性检查

#### 7. 国际化（i18n）审计

- **当前状态：** 零覆盖
- **建议实现方式：** Skill + 脚本（翻译文件完整性、硬编码字符串检测、LTR/RTL 布局检查、复数规则验证）
- **重要性：** 国际化产品刚需，且容易在开发中被忽略

#### 8. 无障碍（A11y）深度审计 Skill

- **当前状态：** `a11y-architect` agent 存在（WCAG 2.2，Web/Native），但它是 agent 而非可调用的审查 skill
- **建议实现方式：** Skill（与 a11y-architect agent 互补，提供脚本自动化检查 + 检查清单）
- **覆盖范围：** ARIA 验证、键盘导航、色彩对比度、屏幕阅读器兼容、焦点顺序

#### 9. 配置管理审计

- **当前状态：** `harness-score` 仅覆盖 harness 配置，无通用配置审计
- **建议实现方式：** Skill（环境差异检测、feature flag 审计、密钥轮换提醒、跨服务配置一致性）

---

### P2 — 中等优先级（锦上添花）

#### 10. 静态分析结果聚合

- **现有问题：** ESLint/SonarQube/Semgrep/clang-tidy 各输出不同格式，缺乏统一视图
- **建议实现方式：** Skill（聚合多工具输出、去重、趋势追踪、actionable 修复方案）
- **与 `tech-debt-scanner` 的关系：** 互补 — tech-debt-scanner 做语言级通用扫描，此 skill 整合已有工具链

#### 11. 性能回归检测

- **当前状态：** `performance-optimizer` 做当前性能分析，不做回归追踪
- **建议实现方式：** Skill（基准对比、性能预算设定、回归告警、Lighthouse 趋势图）

#### 12. 迭代/Sprint 规划助手

- **当前状态：** `project-flow-ops` + `jira-integration` skill 存在但不完整
- **建议实现方式：** Skill/Agent（从 PRD/Story 生成任务拆分、依赖识别、故事点估算、速率追踪）

#### 13. 事件复盘 / Postmortem 模板

- **建议实现方式：** Skill（分析事件时间线、关联部署变更、识别根因模式、生成无责事后分析文档）

---

### P3 — 低优先级（利基/未来储备）

| 缺口 | 说明 |
|------|------|
| 模糊测试 / 属性测试 | Property-based testing 发现边界用例，但需要深度领域知识 |
| IaC 审计（Terraform/Pulumi） | 需要较多的运维知识，当前技能树不匹配 |
| 可观测性 / 日志分析 | 需要成熟的可观测性基础设施，当前团队不涉及 |
| 品牌语调合规 | `brand-voice` skill 存在，无需新建 |
| WTF-per-Minute 趣味审查 | 纯团队文化建设 |

---

## 四、建议建设路线图

```
第1批（立即）:
  ├── P0-1: Commit/PR 自动生成 agent
  ├── P0-2: 依赖供应链安全审计 skill
  └── P0-4: 部署与运维 agent

第2批（1-2周内）:
  ├── P0-3: 数据库 Migration 审查 agent
  ├── P1-5: Changelog 自动生成 skill
  └── P1-6: API 契约验证 skill

第3批（按需）:
  ├── P1-7: i18n 审计 skill
  ├── P1-8: A11y 深度审计 skill（补充 a11y-architect agent）
  └── P1-9: 配置管理审计 skill

远期（资源允许时）:
  ├── P2-10: 静态分析聚合 skill
  ├── P2-12: Sprint 规划 agent
  └── P2-11: 性能回归检测 skill
```

---

## 五、关于 Agent vs Skill 的选型建议

| 特征 | 推荐 Agent | 推荐 Skill |
|------|-----------|-----------|
| 需要分析/推理/决策 | ✅ | ❌ |
| 需要调用多个工具协调 | ✅ | ❌ |
| 提供分步检查清单 + 脚本 | ❌ | ✅ |
| 可被 eval 用例量化评估 | ❌ | ✅（配合 skill-evolve） |
| 用户需要交互式确认 | ✅ | ✅ |
| 触发频率高、响应要快 | ❌ | ✅（更快） |

**P0 缺口中的选型判断：**
- Commit/PR 生成 → **Agent**（需要分析 diff 并理解代码语义）
- 依赖安全审计 → **Skill**（扫描脚本 + 检查清单模式，适合 eval 门控）
- 数据库 Migration → **Agent**（需要理解 schema 变更影响面，判断安全性）
- 部署运维 → **Agent**（需要上下文推理和决策）

---

## 六、关键发现总结

1. **代码审查维度过于饱和**（11个 reviewer agent + 6个审查 skill），而部署运维几乎是空白
2. **面向"写代码"的工具体系完善**，但"写代码之前"（需求/设计）和"写代码之后"（部署/运维/沟通）的工具明显不足
3. **安全维度存在盲区** — 源码审查完善但供应链安全缺失
4. **日常高频操作未覆盖** — 提交信息、PR 描述是每次必做操作，却没有专用工具
5. **已有 a11y-architect agent**（agent 2 发现），但它与可调用的审查 skill 是互补关系，可考虑建设配套 skill
