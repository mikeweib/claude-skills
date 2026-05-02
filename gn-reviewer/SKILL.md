---
name: gn-reviewer
description: Use when reviewing BUILD.gn or .gni files for correctness — import paths, dependency declarations (deps vs public_deps), target type selection, config scoping, visibility rules, source file existence, testonly flags, and WebRTC-specific conventions (rtc_source_set, rtc_static_library, webrtc.gni). Also triggers when adding or modifying GN build targets in Chromium/WebRTC-derived projects. Symptoms: link errors from missing deps, header visibility issues, duplicate target names, incorrect config propagation.
---

# GN 构建文件审查

## Overview

GN (Generate Ninja) 是 Chromium/WebRTC 生态的元构建系统。BUILD.gn 和 .gni 文件的错误往往只在链接阶段才暴露，反馈周期长。审查时必须逐项确认以下规则。

## When to Use 触发条件

- 新增或修改 `BUILD.gn` / `*.gni` 文件
- 链接错误排查（missing symbol、duplicate symbol）
- header 找不到（include path 问题）
- 条件编译未生效
- 新增 third_party 依赖的 GN 集成

**不使用的情况：**
- CMake / Makefile / Bazel 等其他构建系统
- 纯 Ninja 文件审查
- GN 本身的源码修改（`.gn` 根配置文件配置语法不同）

## Review Workflow 审查流程

按优先级从高到低，每一步出问题即报告，不必继续后续步骤。

### Step 1: Import 路径验证

检查所有 `import()` 语句：

1. **路径存在性**：search 确认 `import("//path/to/file.gni")` 中的文件存在
2. **条件 import**：`if (is_android) { import(...) }` 是否平台条件正确
3. **重复 import**：同一文件是否被多次 import
4. **缺失 import**：使用了 `rtc_source_set` / `rtc_static_library` 等模板但未 `import("//webrtc.gni")`

**输出：** 缺失/多余的 import 列表。

### Step 2: Target 定义检查

检查每个 target 定义的完整性：

1. **Target 类型选择**：
   - `source_set`：仅被同一 BUILD.gn 内 target 依赖的源文件集合（轻量，无独立库）
   - `static_library`：需要独立 `.a` / `.lib` 输出
   - `shared_library`：需要 `.so` / `.dll` 输出
   - `rtc_source_set` / `rtc_static_library`：WebRTC 项目的封装模板，提供默认 config
   - `executable`：可执行文件
   - `group`：纯依赖聚合，无源文件

2. **Target 命名**：是否与同文件中其他 target 重名

3. **`sources` 字段**：
   - 是否为空（group 除外）
   - 文件路径是否存在
   - 是否引用了非本目录文件（应通过 deps 引入）

4. **`complete_static_lib`**：`rtc_static_library` 配合 `complete_static_lib = true` 是否正确

**输出：** target 类型/命名/源文件问题。

### Step 3: 依赖声明正确性

检查 `deps` / `public_deps` / `allow_circular_includes_from`：

1. **deps vs public_deps**：header 被本 target 的 public header 引用时，必须用 `public_deps` 而非 `deps`
2. **传递依赖缺失**：A 依赖 B，B 的 public header 引用 C 的 header → A 需要 `public_deps` B 或 B 的 `public_deps` 包含 C
3. **循环依赖**：`deps` 中是否直接/间接引用了自身（检查组内）
4. **未定义的依赖 target**：`deps += [ "${rtc_xxx_dir}:some_target" ]` 中变量或 target 是否存在
5. **`testonly` 泄漏**：标记 `testonly = true` 的 target 被非测试 target 依赖

**输出：** deps/public_deps 混淆 / 缺失依赖 / 循环依赖 / testonly 泄漏。

### Step 4: Config 作用域检查

检查 `config` / `public_config` / `all_dependent_configs`：

1. **config vs public_config**：
   - `config`：仅本 target 生效
   - `public_config`：传播给依赖本 target 的所有 target
   - compiler flags / system defines 通常用 `public_config`

2. **`all_dependent_configs` 滥用**：会传播到整个依赖链，应谨慎使用

3. **config 定义位置**：`config("name") {}` 是否在引用前定义

4. **重复 config 推送**：`configs += [ ":xxx" ]` 和 `public_configs += [ ":xxx" ]` 是否同时存在造成重复

**输出：** config/public_config 混淆 / 过度传播 / 未定义引用。

### Step 5: 可见性与条件编译

1. **`visibility`**：
   - 默认仅对同 BUILD.gn 内可见
   - `visibility = [ "*" ]` 全局可见是否必要
   - `visibility = [ ":*" ]` 同文件内可见
   - 语法错误：`visibility = "*"`（缺少列表）

2. **条件编译**：
   - `if (is_win) { sources += [...] }` 平台变量是否正确
   - `if (current_cpu == "x64")` CPU 条件
   - `declare_args()` 中声明的变量是否在使用前定义
   - 条件分支中 deps 的 target 是否在对应平台存在

3. **`testonly`**：测试 target 是否标记 `testonly = true`

**输出：** visibility 错误 / 条件变量未定义 / testonly 缺失。

### Step 6: 跨文件检查

1. **模板调用**：`template("xxx")` 定义的文件是否被 import
2. **`.gni` 变量使用**：`declare_args()` 声明与实际使用是否一致
3. **`assert()` 逻辑**：条件断言是否正确（类型、逻辑错误）
4. **`read_file()` 路径**：读取的 JSON/配置文件路径是否正确

**输出：** 模板未 import / 变量未声明 / assert 错误。

## 核心检查清单

审查时对照此清单，与上述流程配合：

- [ ] **Import 路径（import path）** —— 所有 `import()` 路径指向真实文件，WebRTC 模板文件已 import
- [ ] **Target 类型（target type）** —— 正确使用 `source_set` vs `static_library` vs `group`
- [ ] **deps vs public_deps** —— public header 依赖的 target 在 `public_deps` 中声明
- [ ] **源文件存在（source existence）** —— `sources` 中所有文件路径正确
- [ ] **依赖完整（dep completeness）** —— 所有 `#include` 对应的 target 在 deps 中
- [ ] **Config 传播（config propagation）** —— `public_config` 正确传播，无滥用 `all_dependent_configs`
- [ ] **Visibility** —— 跨 target 引用有正确的 visibility 声明
- [ ] **testonly 标记** —— 测试 target 标记 `testonly = true`，非测试 target 不引用 testonly target
- [ ] **条件编译（conditional）** —— `if` 条件中使用的变量已通过 `declare_args()` 声明
- [ ] **命名唯一（unique name）** —— target 名称在文件内唯一，config 名称不冲突
- [ ] **`complete_static_lib`** —— `rtc_static_library` + `complete_static_lib = true` 时理解其含义

## Quick Reference 速查

| 场景 | 正确做法 | 禁止 |
|------|---------|------|
| 源文件被多个 target 使用 | `source_set("common")` + `deps += [":common"]` | 在多个 target 中重复列出相同源文件 |
| header 暴露给外部 | `public_deps = [":dep"]` | `deps = [":dep"]`（导致传递依赖缺失） |
| 纯依赖聚合 | `group("all") { deps = [...] }` | 建一个空的 `static_library` |
| 编译选项传播 | `public_configs = [":my_config"]` | `configs = [":my_config"]`（仅本 target） |
| 测试代码隔离 | `testonly = true` | 非测试 target 依赖 testonly target |
| 跨目录 target 引用 | `deps = ["//path/to:target"]` + 设置 visibility | 缺少 visibility 声明 |
| 条件平台源码 | `if (is_win) { sources += [...] }` | 放在 sources 中不区分平台 |
| WebRTC 源文件集 | `rtc_source_set("name")` | 裸 `source_set("name")`（缺少 WebRTC 默认 config） |
| 预定义变量判断 | `if (is_clang)` / `if (is_win)` | 硬编码平台假设 |
| template 定义 | 放在 `.gni` 文件中，BUILD.gn 中 import | 在 BUILD.gn 中定义 template |

## Common Mistakes 常见错误

| 错误 | 为什么错 | 正确做法 |
|------|---------|---------|
| 使用 `deps` 当 header 暴露给外部 | 依赖 target 的 header 对使用者不可见，编译报 missing header | 改用 `public_deps` |
| 忘记 `import("//webrtc.gni")` | `rtc_source_set` 等模板未定义，GN 报 unknown function | 在文件顶部添加 `import("//webrtc.gni")` |
| `visibility = "*"` 而非 `[ "*" ]` | GN 语法要求 list，`"*"` 是 string 类型不匹配 | `visibility = [ "*" ]` |
| `source_set` 暴露为 shared_library 依赖 | `source_set` 源码会被链接到每个依赖者，可能导致符号重复 | 改用 `static_library` 或被多个 shared_library 依赖时注意 |
| 测试 target 未标记 `testonly` | 通过 deps 链可能被 release build 引入 | 添加 `testonly = true` |
| `all_dependent_configs` 传播编译选项 | 影响整个依赖树，可能导致意外的编译行为 | 改用 `public_configs` + 在需要者中显式添加 |
| `declare_args()` 声明后未检查类型 | 外部 gn args 可传任意类型，可能导致运行时错误 | 使用 `assert(is_xxx)` 验证关键值 |
| 条件 import 放在非条件代码中 | 平台特定 .gni 在其他平台不存在 | `if (is_android) { import(...) }` |
| 在 `BUILD.gn` 中定义 `template()` | template 定义应在 .gni 中，才能被其他文件 import | 提取到 `xxx.gni`，在需要的 BUILD.gn 中 import |
| `read_file()` 路径不在 `//` 开头 | 相对路径依赖 CWD，不同构建目录结果不同 | 使用 `//` 开头的绝对路径 |

## References 参考文件

- **[gn-syntax-quickref.md](references/gn-syntax-quickref.md)** — GN 语法速查：变量、条件、模板、函数
- **[webrtc-gn-patterns.md](references/webrtc-gn-patterns.md)** — WebRTC 项目的 GN 特殊约定
