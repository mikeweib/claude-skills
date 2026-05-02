# GN 语法速查

## 基本概念

GN 文件使用类似 Python 的语法，生成 Ninja 构建文件。

## 变量与类型

```gn
# 字符串
name = "hello"
path = "//path/to/something"

# 布尔
is_enabled = true

# 列表
sources = [ "a.cc", "b.cc" ]
deps = [
  ":target1",
  "//path/to:target2",
]

# 列表拼接
deps += [ ":extra_dep" ]
sources -= [ "remove_me.cc" ]

# Scope / 字典
config("my_config") {
  defines = [ "MY_DEFINE" ]
}
```

## 条件表达式

```gn
# 平台变量（内置）
if (is_win) { ... }
if (is_mac) { ... }
if (is_linux) { ... }
if (is_ios) { ... }
if (is_android) { ... }
if (is_chromeos) { ... }
if (is_posix) { ... }    # mac + linux + ios + android + chromeos

# 编译器变量
if (is_clang) { ... }
if (is_gcc) { ... }
if (is_msvc) { ... }

# CPU 架构
if (current_cpu == "x64") { ... }
if (current_cpu == "x86") { ... }
if (current_cpu == "arm") { ... }
if (current_cpu == "arm64") { ... }

# 自定义变量（来自 declare_args）
if (rtc_enable_sctp) { ... }
```

## declare_args() 语法

```gn
# 在 .gni 文件中声明可被外部覆盖的构建参数
declare_args() {
  # 变量名 = 默认值
  rtc_enable_sctp = false
  rtc_build_opus = true
  rtc_sanitize_coverage = ""
}
```

## Target 类型

```gn
# 1. source_set — 源文件集合，被链接到依赖者中（无独立库文件）
source_set("my_utils") {
  sources = [ "utils.cc", "utils.h" ]
  deps = [ ":base" ]
}

# 2. static_library — 静态库 .a / .lib
static_library("my_lib") {
  sources = [ "lib.cc" ]
  public = [ "lib.h" ]      # public headers（可选）
  deps = [ ":utils" ]
}

# 3. shared_library — 动态库 .so / .dll
shared_library("my_dll") {
  sources = [ "dll.cc" ]
  deps = [ ":utils" ]
}

# 4. executable — 可执行文件
executable("my_app") {
  sources = [ "main.cc" ]
  deps = [ ":my_lib" ]
}

# 5. group — 纯依赖聚合
group("all") {
  deps = [
    ":my_lib",
    ":my_app",
  ]
  testonly = true   # 如果聚合的是测试 target
}

# 6. config — 编译/链接配置
config("my_config") {
  defines = [ "MY_DEFINE" ]
  cflags = [ "-Wall" ]
  include_dirs = [ "//third_party/foo/include" ]
  ldflags = [ "-lpthread" ]
}
```

## 依赖声明

```gn
# 同文件内 target
deps = [ ":other_target" ]

# 同文件内但路径确定
deps = [ "subdir:target_name" ]

# 跨目录（绝对路径）
deps = [ "//path/to/dir:target_name" ]

# 变量引用
deps = [ tutor_log_dir ]         # 变量值本身就是 ":target" 或 "//path:target"
deps += [ "${rtc_opus_dir}:opus" ]  # 字符串拼接

# deps vs public_deps
source_set("A") {
  deps = [ ":B" ]          # B 仅 A 内部可见
  public_deps = [ ":C" ]   # C 的 header 和 config 传播给 A 的使用者
}

# allow_circular_includes_from — 允许的头文件循环引用
source_set("A") {
  allow_circular_includes_from = [ ":B" ]
}
```

## Config 传播

```gn
config("my_defines") {
  defines = [ "ENABLE_FOO=1" ]
}

source_set("lib") {
  # configs: 仅本 target 的编译选项
  configs += [ ":my_defines" ]

  # public_configs: 传播给依赖本 target 的所有 target
  public_configs = [ ":my_defines" ]

  # all_dependent_configs: 传播给整个依赖链（非常强力，避免滥用）
  all_dependent_configs = [ ":my_defines" ]
}
```

## Visibility（可见性）

```gn
# 默认：仅同 BUILD.gn 内可见

# 全局可见
visibility = [ "*" ]

# 同文件内可见
visibility = [ ":*" ]

# 指定 target 可见
visibility = [
  ":target_a",
  "//other/dir:target_b",
]

# 指定目录下所有 target 可见
visibility = [ "//other/dir:*" ]
```

## Template（模板）

```gn
# 定义在 .gni 文件中
template("my_custom_target") {
  source_set(target_name) {
    forward_variables_from(invoker,
                           "*",
                           [
                             "excluded_var",
                           ])
    sources = invoker.sources + [ "extra.cc" ]
    defines = [ "EXTRA_DEFINE" ]
  }
}

# 使用
my_custom_target("foo") {
  sources = [ "foo.cc" ]
  excluded_var = "not_passed_through"
}
```

## 常用函数

```gn
# assert — 断言
assert(is_clang, "This target requires clang")
assert(defined(rtc_opus_dir), "rtc_opus_dir must be defined")

# read_file — 读取文件
json_data = read_file("//path/to/file.json", "json")
text_data = read_file("//path/to/file.txt", "scope")  # 解析为 GN scope

# foreach — 遍历
foreach(source, my_sources) {
  sources += [ source ]
}

# exec_script — 执行外部脚本
result = exec_script("//build/script.py", [ arg1, arg2 ], "json")

# string_replace — 字符串替换
gn_path = string_replace(system_path, "/home/user", "//")

# get_path_info — 路径信息提取
dir = get_path_info("//path/to/file.cc", "dir")
name = get_path_info("//path/to/file.cc", "name")
ext = get_path_info("//path/to/file.cc", "extension")
```

## 常见内置变量

```gn
root_build_dir      # 构建输出根目录
target_out_dir      # 当前 target 的输出目录
current_cpu         # 当前 CPU 架构
current_os          # 当前操作系统
host_cpu            # 主机 CPU
host_os             # 主机 OS
target_cpu          # 目标 CPU
target_os           # 目标 OS
python_path         # Python 解释器路径
```

## 路径规则

```gn
# "//" 开头 — 相对于项目根目录（.gn 文件所在目录）
import("//build/config/arm.gni")
source = "//third_party/lib/src/file.cc"

# ":" 开头 — 同 BUILD.gn 内的 target
deps = [ ":my_target" ]

# 相对路径 — 相对于当前 BUILD.gn 所在目录
sources = [ "src/file.cc", "src/file.h" ]
```
