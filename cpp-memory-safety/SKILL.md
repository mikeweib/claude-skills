---
name: cpp-memory-safety
description: Use when writing or reviewing C++ code that involves raw pointers, smart pointers (shared_ptr/unique_ptr/weak_ptr), dynamic memory allocation, arrays, resource management, or move semantics. Also triggers when the project depends on WebRTC (use rtc::scoped_refptr instead of std::shared_ptr). Symptoms: memory leak, use-after-free, double-free, dangling pointer, data race.
---

# C++ 内存安全检查

## Overview

C++ 内存安全问题是最高频的 bug 来源。审查代码时必须逐项确认以下规则。

## When to Use 触发条件

- 代码中出现 `new` / `delete` / `malloc` / `free`
- 代码中有 raw pointer（裸指针）操作
- 代码中使用 `std::shared_ptr` / `std::unique_ptr` / `std::weak_ptr`
- 数组访问、缓冲区操作
- RAII 资源管理

**不使用的情况：**
- 纯现代 C++（完全使用 smart pointer + STL，无 raw pointer）—— 基本无需此 skill
- 纯 C 代码 —— 使用不同的规则集

## Review Workflow 审查流程

按优先级从高到低，每一步出问题即报告，不必继续后续步骤。

### Step 1: 定位裸内存操作

搜索代码中的 `new` / `delete` / `malloc` / `free` / `realloc`。没有裸内存操作 → 跳到 Step 3。

**自动化：** 运行 `scripts/scan-raw-memory.sh [directory]` 快速扫描所有裸内存操作。

**输出：** 裸内存操作列表（文件:行号）。

### Step 2: 所有权配对

每个 `new` / `malloc` 找到对应的 `delete` / `free`。检查：
- 释放是否在所有执行路径上都发生（包括异常路径）
- 是否匹配：`new` ↔ `delete`，`new[]` ↔ `delete[]`，`malloc` ↔ `free`
- 能找到配对 → 改用 `std::make_unique` / `std::make_shared` 消除配对负担

**输出：** 无配对的操作清单 = 内存泄漏点。

### Step 3: Smart Pointer 选择检查

无论是否有裸内存操作，始终检查：

**自动化：** 运行 `scripts/find-shared-ptr-overuse.sh [directory]` 统计所有 `shared_ptr` 使用。WebRTC 项目加 `--webrtc` 标记。

1. **过度使用 `shared_ptr`**：仅在真正需要共享所有权时用 `shared_ptr`，能用 `unique_ptr` 的不要用 `shared_ptr`（性能开销大、语义不清晰）
2. **WebRTC 工程专项**：如果项目依赖 webrtc 库，**禁止使用 `std::shared_ptr`**，必须使用 `rtc::scoped_refptr<T>`。WebRTC 有自己的引用计数基类 `rtc::RefCountInterface`，与 `std::shared_ptr` 的控制块不兼容
3. **`weak_ptr` 打破循环引用**：当两个对象互相引用时，一方用 `weak_ptr` 避免循环
4. **`make_unique` / `make_shared` 优先**：比裸 `new` 更安全（异常安全、一次分配优化）

**输出：** `shared_ptr` 过度使用 / WebRTC 项目使用了 `std::shared_ptr` / 循环引用风险。

### Step 4: 类级别检查（class 有 raw pointer 成员时）

**自动化：** 运行 `scripts/check-rule-of-five.sh [directory]` 检查所有含 raw pointer 成员的 class 的 Rule of Five 状态。

1. **Rule of Five**：destructor / copy ctor / copy assign / move ctor / move assign 是否齐全或 `= delete`
2. **Move 语义**：move ctor / move assign 是否将源对象 raw pointer 置 `nullptr`
3. **浅拷贝**：拷贝后两个对象的 raw pointer 是否指向同一块内存

**输出：** 违反 Rule of Five / move 未清空源指针 / 浅拷贝风险。

### Step 5: 访问安全

1. **数组边界**：`[]` 访问的下标是否可能越界，`new[]` 分配大小与访问范围是否一致
2. **空指针**：解引用前是否已判空（函数参数、返回值、条件分支）
3. **悬空指针**：`delete` 后是否继续使用，是否返回了局部变量地址，是否保存了临时对象引用

**输出：** 越界 / 空解引用 / 悬空指针风险点。

### Step 6: 跨函数检查

1. **异常安全**：裸 `new` 和配对的 `delete` 之间是否可能抛异常导致泄漏
2. **并发**：多线程路径中是否有 data race，`shared_ptr` 共享数据是否加锁

**输出：** 异常路径泄漏 / data race 风险。

## 核心检查清单

审查时对照此清单，与上述流程配合：

- [ ] **Smart Pointer 选择（smart pointer selection）** —— 能用 `unique_ptr` 的不要用 `shared_ptr`；WebRTC 工程必须用 `rtc::scoped_refptr<T>` 替代 `std::shared_ptr<T>`
- [ ] **所有权清晰（ownership）** —— 每个 `new` 有对应的 `delete`，或用 smart pointer 管理
- [ ] **数组边界（array bounds）** —— 所有 `[]` 访问有边界检查或明确保证不越界
- [ ] **空指针（null pointer）** —— 解引用前检查是否为 `nullptr`
- [ ] **悬空指针（dangling pointer）** —— `delete` 后将指针置为 `nullptr`，不保存临时对象地址
- [ ] **浅拷贝问题（shallow copy）** —— 有 raw pointer 成员的 class 必须有自定义 copy constructor / copy assignment，或 `= delete`
- [ ] **异常安全（exception safety）** —— `new` 和 `delete` 之间如果抛出异常，资源是否泄漏
- [ ] **Move 语义陷阱（move semantics）** —— move constructor / move assignment 中是否将源对象的 raw pointer 置 `nullptr`，moved-from 对象是否仍处于可析构状态
- [ ] **并发内存问题（concurrency）** —— 多线程访问共享数据是否存在 data race（= UB），`shared_ptr` 引用计数线程安全但指向数据是否加锁保护

## Quick Reference 速查

| 场景 | 做什么 | 禁止 |
|------|--------|------|
| 独占所有权 | `std::unique_ptr<T>` | `std::shared_ptr<T>`（无需共享时） |
| 共享所有权（通用） | `std::shared_ptr<T>` + `std::weak_ptr<T>` 打破循环 | 裸 `new` + 手动 `delete` |
| 共享所有权（WebRTC） | `rtc::scoped_refptr<T>`，对象继承 `rtc::RefCountInterface` | `std::shared_ptr<T>`（控制块不兼容） |
| 动态对象 | `std::make_unique<T>()` / `std::make_shared<T>()` | 裸 `new` |
| 动态数组 | `std::vector<T>` | `new T[]` |
| 资源句柄 | RAII wrapper class | 裸 `malloc` / `free` |
| 观察引用 | `T*` 标注 `owner=false` 或 `std::optional<std::reference_wrapper<T>>` | 用引用接收可能为空的场景 |
| 缓存/临时引用 | `std::weak_ptr<T>` | raw pointer 存储长生命周期对象引用 |
| Move 后源对象 | 将源对象的 raw pointer 成员置 `nullptr` | 不处理源对象，析构时 double-free |
| 多线程共享数据 | `std::shared_ptr<T>` + mutex 保护数据，或 `std::atomic<std::shared_ptr<T>>`（C++20） | 多线程直接读写 `shared_ptr` 指向的数据 |

## Common Mistakes 常见错误

| 错误 | 为什么错 | 正确做法 |
|------|---------|---------|
| 不需要共享所有权时用 `shared_ptr` | 引用计数开销大、语义模糊、无法优化为 `unique_ptr` | 默认用 `unique_ptr`，只在真正需要共享时用 `shared_ptr` |
| WebRTC 工程中用 `std::shared_ptr` | WebRTC 有独立的引用计数系统（`rtc::RefCountInterface`），控制块不兼容，混用导致 double-free 或泄漏 | 全部改用 `rtc::scoped_refptr<T>`，对象继承 `rtc::RefCountInterface` |
| 构造函数中裸 `new` 后抛异常 | 资源泄漏，destructor 不会被调用 | 用 smart pointer 成员，或在 catch 块中 `delete` |
| `delete ptr` 后继续使用 `ptr` | dangling pointer，undefined behavior | `delete` 后立即置 `nullptr` |
| 返回局部变量的地址/引用 | 栈上对象已销毁 | 按值返回，或用 `std::shared_ptr` |
| 忘记 Rule of Five | shallow copy 导致 double-free | 有 raw pointer 成员时实现或 `= delete` 全部五个 |
| `shared_ptr` 循环引用 | memory leak | 一方改用 `weak_ptr` |
| Move constructor 未将源对象 raw pointer 置 `nullptr` | moved-from 对象的 destructor 仍会 `delete`，导致 double-free | 移动后源指针置 `nullptr`：`other.ptr = nullptr;` |
| 多线程读写 `shared_ptr` 指向的数据未加锁 | data race = undefined behavior。`shared_ptr` 只保证引用计数原子性，不保护指向的数据 | 加 `std::mutex` 保护数据，或用 `std::atomic` 对简单类型 |

## Scripts 自动化脚本

审查时可配合以下脚本快速定位问题：

| 脚本 | 用途 | 对应 Step |
|------|------|-----------|
| `scripts/scan-raw-memory.sh [dir]` | 扫描所有 `new`/`delete`/`malloc`/`free` | Step 1 |
| `scripts/find-shared-ptr-overuse.sh [dir] [--webrtc]` | 统计 `shared_ptr` 使用，WebRTC 项目检查误用 | Step 3 |
| `scripts/check-rule-of-five.sh [dir]` | 检查含 raw pointer 成员的 class 的 Rule of Five | Step 4 |

脚本输出均为 `file:line` 格式，方便直接跳转审查。

## References 参考文件

- **[bug-patterns.md](references/bug-patterns.md)** — 9 个检查维度的 bad/good 代码对比，审查时可直接对照
