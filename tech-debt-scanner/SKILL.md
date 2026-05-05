---
name: tech-debt-scanner
description: Use when the user asks to scan, audit, or score a project's technical debt — e.g. "扫描技术债", "代码质量评分", "检查技术债", "tech debt audit", "工程健康度". Runs deterministic shell scripts to detect marker comments (TODO/FIXME/HACK), dead code, complexity violations, and deprecated API usage across multiple languages (C/C++, Java, Python, JS/TS, Go, Rust, Swift, C#). Outputs a 0-100 score with A-F grade and per-category detailed report with file:line locations.
---

# 技术债扫描

## Overview

对项目进行四维度的技术债扫描，给出 0-100 的量化评分和 A-F 等级。扫描覆盖标记注释、死代码、复杂度、废弃 API 四类，支持 C/C++、Java、Python、JS/TS、Go、Rust 等主流语言。

## When to Use 触发条件

- 用户要求"扫描技术债"、"代码质量评分"、"检查技术债"、"工程健康度"
- 项目健康度定期审查
- 新成员接手项目时评估代码库状态
- 合并前的质量检查

**不使用的情况：**
- 单一文件代码审查（使用语言专用 review skills）
- 安全漏洞扫描（使用 `security-review` skill）
- 仅需代码格式化/风格检查（使用项目 linter）
- 构建错误排查（使用 `build-error-resolver` agent）

## Scoring Workflow 评分流程

### Step 1: 环境预检

确认扫描条件并检测项目语言组成：

**自动化：** 运行 `scripts/preflight-check.sh [project_dir]` 一键完成环境预检。

1. 验证目标目录存在
2. 自动检测项目语言（按文件扩展名统计）
3. 计算总文件数和代码行数
4. 确认排除目录（node_modules/、vendor/、.git/ 等）

**输出：** 检测到的语言列表 / 文件数 / 代码量 / 就绪状态。

### Step 2: 标记注释扫描（权重 25%）

**自动化：** 运行 `scripts/scan-marker-comments.sh [project_dir]` 扫描所有标记注释。

搜索代码中的临时标记注释，按严重程度分级扣分：

| 级别 | 标记 | 扣分 | 上限 |
|------|------|------|------|
| 严重 | FIXME, HACK | -3 分/条 | -9 |
| 显著 | XXX, TEMP, KLUDGE, BUG, OPTIMIZE, WORKAROUND | -2 分/条 | -8 |
| 中等 | TODO | -1 分/条 | -8 |

**过滤规则：**
- 排除 URL 中的关键字（如 `https://` 包含 TODO 不会触发）
- 排除 license 头中的关键字
- 排除脚本自身的注释（脚本内联代码中的标记）

**得分低的原因：**
- 代码中遗留大量 FIXME/HACK → 已知问题未修复
- TODO 密度过高（>5 条/千行）→ 大量功能待完成
- 存在 TEMP/KLUDGE 标记 → 临时方案未清理

### Step 3: 死代码检测（权重 25%）

**自动化：** 运行 `scripts/scan-dead-code.sh [project_dir] [--threshold N]` 检测死代码。

| 检测项 | 扣分 | 上限 |
|--------|------|------|
| 注释代码块（>=10 行连续注释） | -3 分/块 | -9 |
| 空 catch 块 | -2 分/条 | -8 |
| 死条件（if(false)/if(0)） | -3 分/条 | -6 |
| return 后不可达代码 | -1 分/条 | -2 |

**得分低的原因：**
- 大量注释掉的代码 → 代码腐烂，引用的符号可能已变更
- 空 catch 块吞异常 → 错误被静默忽略
- if(false) 块 → 死代码未清理

### Step 4: 复杂度分析（权重 25%）

**自动化：** 运行 `scripts/scan-complexity.sh [project_dir]` 分析代码复杂度。

| 检测项 | 阈值 | 扣分 | 上限 |
|--------|------|------|------|
| 超大文件 | >800 行 | -2 分/文件 | -8 |
| 长函数 | >50 行 | -1 分/函数 | -8 |
| 深层嵌套 | >=4 层 | -2 分/处 | -5 |
| 过多参数 | >=5 个 | -1 分/函数 | -4 |

**排除规则：** 自动跳过生成文件（`*generated*`、`*.pb.*`、`*.g.*`）。

**得分低的原因：**
- 单文件过大 → 职责不清，应拆分
- 函数过长 → 逻辑复杂，难以理解和测试
- 嵌套过深 → 圈复杂度高，容易出错
- 参数过多 → 函数接口复杂，考虑封装为结构体/对象

### Step 5: 废弃 API 扫描（权重 25%）

**自动化：** 运行 `scripts/scan-deprecated-api.sh [project_dir]` 扫描废弃 API。

| 检测项 | 扣分 | 上限 |
|--------|------|------|
| @deprecated / #[deprecated] 注解标记 | -3 分/条 | -12 |
| 已知废弃 API 调用 | -2 分/条 | -13 |

**覆盖的废弃 API 包括：**

| 语言 | 示例 |
|------|------|
| C/C++ | `gets()`, `sprintf()`, `strcpy()`, `strcat()`, `tmpnam()` |
| Python | `distutils`, `imp`, `start_new_thread`, `getargspec` |
| JS/TS | `document.write()`, `arguments.callee`, `unescape()` |
| Java | `new Date()`, `Thread.stop()`, `Vector`, `Hashtable` |
| Go | `ioutil.ReadAll`, `ioutil.ReadFile` 等 |
| Rust | `std::mem::uninitialized`, `std::env::home_dir` |

**得分低的原因：**
- 大量使用 @deprecated 标记的 API → 依赖即将被移除
- 使用已知不安全的 C 函数 → 缓冲区溢出风险
- Python `distutils` → Python 3.12 已移除

### Step 6: 等级评定与报告

汇总 4 个类别的得分（满分 100），转换为等级：

| 得分率 | 等级 | 含义 | 行动 |
|--------|------|------|------|
| >= 90% | **A** | 优秀 — 技术债可控 | 保持当前实践 |
| >= 70% | **B** | 良好 — 少量技术债 | 优先处理 FIXME/HACK |
| >= 50% | **C** | 一般 — 技术债积累中 | 按优先级逐项清理 |
| >= 30% | **D** | 较差 — 大量技术债 | 从标记清理和死代码删除开始 |
| < 30% | **F** | 严重 — 急需重构 | 立即处理所有类别 |

**报告结构：**
1. **总分概览** — 总分、等级、检测到的语言
2. **逐类明细** — 每个类别的得分/扣分详情
3. **Top 5 问题** — 按严重程度排序的最严重发现
4. **改进路线图** — 按 ROI 排序的修复建议

## 核心检查清单

审查时对照此清单：

- [ ] **标记注释（marker comments）** — TODO/FIXME/HACK 密度是否健康（<1 条/千行）
- [ ] **死代码（dead code）** — 无大段注释代码块、无空 catch、无死条件
- [ ] **复杂度（complexity）** — 文件 <800 行、函数 <50 行、嵌套 <4 层、参数 <5 个
- [ ] **废弃 API（deprecated API）** — 无 @deprecated 标记使用、无已知不安全函数
- [ ] **排除规则（exclusions）** — 生成文件、第三方代码已被正确排除
- [ ] **密度公平（density fairness）** — 扣分已按项目规模进行密度调整

## Quick Reference 速查

| 类别 | 关键指标 | 健康阈值 | 触发阈值 |
|------|---------|---------|---------|
| 标记注释 | TODO 密度 | <1 条/千行 | >5 条/千行 |
| 标记注释 | FIXME/HACK 数量 | 0 | >3 |
| 死代码 | 注释代码块 | 0 块 >10 行 | >3 块 |
| 死代码 | 空 catch 块 | 0 | >2 |
| 复杂度 | 文件大小 | <500 行 | >800 行/文件 |
| 复杂度 | 函数大小 | <30 行 | >50 行/函数 |
| 废弃 API | @deprecated | 0 | >3 处 |
| 废弃 API | 不安全函数 | 0 | >5 处 |

## Common Issues 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 标记注释得分极低 | 项目中遗留大量 TODO/FIXME | 排序 TODO 列表，优先修复 FIXME/HACK |
| 大型项目得分偏低 | 密度未正确调整 | 增加 --density-cap 参数 |
| 复杂度得分为 0 | 单个超大文件扣分过多 | 拆分超大文件（>800 行）为多个模块 |
| 废弃 API 得分为 0 | 大量使用过时 API | 逐语言迁移到替代 API |
| 扫描脚本无输出 | 项目无支持的源码文件 | 确认项目语言是否在支持列表中 |
| 注释代码块被误报 | 文件头部的 license 注释 | 调整 --threshold 参数 |
| 生成文件被计入复杂度 | 排除模式未匹配 | 添加自定义排除规则 |
| C 项目废弃 API 误报 | 项目已有安全封装 | 手动审查确认是否需扣分 |

## Scripts 自动化脚本

| 脚本 | 用途 | 对应 Step |
|------|------|-----------|
| `scripts/preflight-check.sh [dir]` | 环境预检，语言检测，文件统计 | Step 1 |
| `scripts/scan-marker-comments.sh [dir]` | 扫描 TODO/FIXME/HACK/XXX 等标记注释 | Step 2 |
| `scripts/scan-dead-code.sh [dir] [--threshold N]` | 检测注释代码块、空 catch、死条件 | Step 3 |
| `scripts/scan-complexity.sh [dir]` | 分析文件/函数大小、嵌套深度、参数数量 | Step 4 |
| `scripts/scan-deprecated-api.sh [dir]` | 扫描 @deprecated 注解和已知废弃 API | Step 5 |

脚本输出均包含 `file:line` 定位信息，可直接用于导航和修复。

## References 参考文件

- **[debt-patterns.md](references/debt-patterns.md)** — 按语言分类的技术债模式：标记注释约定、死代码模式、废弃 API 迁移表、复杂度反模式
