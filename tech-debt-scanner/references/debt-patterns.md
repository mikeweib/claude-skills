# 技术债模式参考

按编程语言分类的常见技术债模式及对应的推荐修复方案。

## C/C++

### 标记注释

| 标记 | 含义 | 严重程度 |
|------|------|----------|
| `// FIXME:` | 已知 bug，必须在发布前修复 | 严重 |
| `// HACK:` | 临时绕过方案，通常脆弱 | 严重 |
| `// TODO:` | 计划中的改进 | 中等 |
| `// XXX:` | 可疑代码，需要审查 | 显著 |
| `// BUG:` | 已确认的缺陷 | 显著 |
| `// WORKAROUND:` | 规避外部问题的代码 | 显著 |
| `// OPTIMIZE:` | 性能优化待做 | 显著 |

### 死代码模式

```
#if 0              ← 预处理器死代码块
void old_func() {   ← 已废弃但未删除的函数
    // ...
}
#endif

if (false) {        ← 编译期排除（模板特化中可能是合法的）
    // dead code
}
```

### 复杂度反模式

- **God class**：头文件+实现超 1000 行的类
- **深层嵌套**：`if-for-if-for-switch` 超 4 层
- **超长参数列表**：函数参数 >= 7 个
- **重复代码块**：3+ 个 target 中相同的 cflags/ldflags

### 废弃 API 迁移

| 废弃 API | 替代方案 | 最低标准 |
|----------|----------|----------|
| `gets()` | `fgets()` | C11 |
| `sprintf()` | `snprintf()` | C99 |
| `strcpy()` | `strncpy()` / `strlcpy()` | C99 / BSD |
| `strcat()` | `strncat()` / `strlcat()` | C99 / BSD |
| `tmpnam()` | `mkstemp()` | POSIX |
| `mktemp()` | `mkstemp()` | POSIX |
| `alloca()` | `malloc()` 或栈上定长数组 | — |
| `asctime()` | `asctime_r()` | POSIX |

## Java

### 标记注释

Java 注释约定与 C/C++ 相同，此外常见：
- `// FIXME` / `// TODO` / `// HACK`
- `@SuppressWarnings("deprecation")` — 标记了但未真正修复

### 死代码模式

```java
// 注释掉的代码块
// public void oldMethod() {
//     doSomething();
// }

// 空 catch 块
try {
    riskyOperation();
} catch (Exception e) {
    // silently ignored
}

// 空 if 体
if (condition) {
    // nothing
} else {
    doWork();
}
```

### 复杂度反模式

- **God class**：单文件超 800 行的 Service/Controller
- **长方法**：超 50 行的业务方法
- **深层嵌套**：Stream 操作链超 5 层
- **过度抽象**：过多的 Interface-Impl 对

### 废弃 API 迁移

| 废弃 API | 替代方案 |
|----------|----------|
| `new Date()` | `java.time.LocalDateTime` / `Instant` |
| `Thread.stop()` | `Thread.interrupt()` + 协作式终止 |
| `Thread.suspend()` / `resume()` | `wait()` / `notify()` + 条件变量 |
| `finalize()` | `Cleaner` 或 try-with-resources |
| `Vector<E>` | `ArrayList<E>` |
| `Hashtable<K,V>` | `HashMap<K,V>` 或 `ConcurrentHashMap<K,V>` |
| `Enumeration<E>` | `Iterator<E>` |
| `StringTokenizer` | `String.split()` 或 `Scanner` |

## Python

### 标记注释

```python
# FIXME: known issue with edge case
# HACK: workaround for upstream bug
# TODO: implement proper validation
# XXX: this is suspicious, revisit
```

### 死代码模式

```python
# 注释掉的函数体
# def old_handler(request):
#     return process(request)

# 空异常处理
try:
    do_something()
except Exception:
    pass  # silently ignored

# 不可达代码
def handler():
    return response
    cleanup()  # never runs
```

### 复杂度反模式

- **超长模块**：单文件超 800 行
- **过深嵌套**：`if-for-try-except-if` 超 4 层
- **过多参数**：函数参数 >= 5 个（考虑用 dataclass 或 TypedDict）
- **God class**：单个类超 300 行

### 废弃 API 迁移

| 废弃 API | 替代方案 |
|----------|----------|
| `distutils` | `setuptools` (Python 3.12+ 已移除) |
| `imp` | `importlib` |
| `thread.start_new_thread()` | `threading.Thread` |
| `BaseException.message` | `str(exception)` |
| `inspect.getargspec()` | `inspect.signature()` |
| `csv.Sniffer()` (部分方法) | 手动检测 |
| `asyncio.get_event_loop()` (部分场景) | `asyncio.run()` |
| `pipes` (3.11) | `shlex` |
| `cgi` (3.13) | `email` / `html` / `urllib` |

## JavaScript / TypeScript

### 标记注释

```js
// FIXME: breaks on Safari < 15
// HACK: ie11 polyfill
// TODO: rewrite with async/await
// XXX: mutates global state, risky
// BUG: incorrect for negative numbers
```

### 死代码模式

```js
// 注释掉的代码
// function legacyInit() {
//     setupLegacy();
// }

// 空 catch
try {
    parse(input);
} catch (e) {
    // silently ignore
}

// Dead condition
if (false && experimentalFlag) {
    runExperiment();
}

// 不可达代码
function getValue() {
    return cachedValue;
    refreshCache();  // unreachable
}
```

### 复杂度反模式

- **回调地狱**：3+ 层嵌套回调（应使用 async/await）
- **巨型组件**：React/Vue 组件超 500 行
- **过深嵌套**：JSX 嵌套超 4 层（提取子组件）
- **过多参数**：函数 >= 5 个参数（考虑 options object）

### 废弃 API 迁移

| 废弃 API | 替代方案 |
|----------|----------|
| `document.write()` | DOM 操作或模板 |
| `arguments.callee` | 命名函数引用 |
| `__proto__` | `Object.getPrototypeOf()` / `Object.setPrototypeOf()` |
| `unescape()` | `decodeURIComponent()` |
| `escape()` | `encodeURIComponent()` |
| `for...in` (数组) | `for...of` 或 `Array.forEach()` |
| `with` 语句 | 显式引用 |
| `var` (现代代码) | `const` / `let` |
| `ReactDOM.render()` (React 18) | `createRoot().render()` |

## Go

### 标记注释

```go
// FIXME: data race under concurrent access
// HACK: deadline set to 30s to avoid upstream timeout
// TODO: implement context cancellation
// BUG: off-by-one when input is empty
```

### 死代码模式

```go
// 未使用的 import（go 编译器会报错，但在注释中仍存在）
// import "old/package"

// 空 error 处理
if err != nil {
    // TODO: handle error
}

// 不可达代码
func process() error {
    return nil
    cleanup()  // unreachable
}
```

### 复杂度反模式

- **超大文件**：单文件超 800 行
- **深层嵌套**：if-err 链超 4 层（提取函数）
- **过多参数**：函数参数 >= 5 个（用 struct 封装）
- **过度使用 interface{}**：应使用泛型或具体类型

### 废弃 API 迁移

| 废弃 API | 替代方案 |
|----------|----------|
| `ioutil.ReadAll` | `io.ReadAll` (Go 1.16+) |
| `ioutil.ReadFile` | `os.ReadFile` (Go 1.16+) |
| `ioutil.WriteFile` | `os.WriteFile` (Go 1.16+) |
| `ioutil.TempDir` | `os.MkdirTemp` (Go 1.17+) |
| `ioutil.TempFile` | `os.CreateTemp` (Go 1.17+) |
| `ioutil.NopCloser` | `io.NopCloser` (Go 1.16+) |
| `ioutil.Discard` | `io.Discard` (Go 1.16+) |
| `bufio.ScanWords` (部分) | 自定义 split function |
| `strings.Title` | `golang.org/x/text/cases` |

## 跨语言通用模式

### 标记注释密度

| 健康度 | TODO 密度 (每千行) |
|--------|-------------------|
| 健康 | < 1 |
| 可接受 | 1-3 |
| 需关注 | 3-5 |
| 需清理 | > 5 |

### 文件大小阈值

| 文件行数 | 评级 |
|----------|------|
| < 300 | 好 |
| 300-500 | 正常 |
| 500-800 | 需关注 |
| 800+ | 应拆分 |

### 异常处理

空 catch 块、`except: pass`、`_ = err` 等静默错误处理是所有语言中的通用问题。每条至少扣 2 分。

### 注释代码块

超 10 行连续注释代码块在所有语言中都是问题——代码腐烂、引用的符号可能已变更或删除。
