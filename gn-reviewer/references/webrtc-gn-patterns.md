# WebRTC 项目的 GN 特殊约定

## WebRTC 自定义模板

WebRTC 在 `//webrtc.gni` 中定义了一组封装模板，优先级高于 GN 原生模板。

### rtc_source_set

```gn
rtc_source_set("my_module") {
  sources = [ "module.cc", "module.h" ]
  deps = [ ":other" ]

  # 自动获得 WebRTC 默认编译选项（common_config, common_inherited_config 等）
  # 自动移除 Chromium 特定 config
  # 支持 complete_static_lib
}
```

**何时使用：** 大部分 WebRTC 内部代码的默认选择。等价于 `source_set` + WebRTC 默认 config。

### rtc_static_library

```gn
rtc_static_library("my_lib") {
  sources = [ "lib.cc" ]
  complete_static_lib = true  # 将 deps 的符号也打包进去
  # 当需要做成完整独立 .a 文件时使用
}
```

**`complete_static_lib` 陷阱：**
- 设为 `true` 时，所有 deps（传递）的 object 文件会打包到此 .a 中
- 如果两个 `complete_static_lib` 都 deps 了同一个 source_set，链接时会有符号重复
- 通常只在顶层 target（最终 SDK 产物）使用

### rtc_shared_library

```gn
rtc_shared_library("my_sdk") {
  sources = [ "api.cc" ]
  deps = [ ":internal" ]
}
```

**注意事项：**
- WebRTC 官方不支持 component build（`is_component_build` 在非 Chromium 下被 assert 拒绝）
- 使用时需理解符号导出规则

### rtc_executable

```gn
rtc_executable("my_test") {
  sources = [ "test.cc" ]
  deps = [ "//testing/gtest" ]
  testonly = true
  configs += [ "//:common_config_warning" ]
}
```

### rtc_test

```gn
# rtc_test 是 rtc_executable 的封装，自动依赖 gtest
rtc_test("my_unittest") {
  sources = [ "module_unittest.cc" ]
  deps = [ ":my_module" ]
  # testonly = true 自动设置
}
```

## 关键 .gni 文件

### `//webrtc.gni` — 核心配置

```gn
import("//webrtc.gni")  # 使用 rtc_* 模板前必须 import
```

声明所有 `rtc_*` 前缀的模板和变量。

### `//tutor_engine.gni` — 项目自定义（live_engine_sdk 特有）

```gn
import("//tutor_engine.gni")
```

定义项目特定变量：`tutor_include_tests`, `tutor_engine_mac_test` 等。

### `//build/config/sanitizers/sanitizers.gni` — 消毒器配置

```gn
import("//build/config/sanitizers/sanitizers.gni")
```

提供 `rtc_sanitize_coverage` 等消毒器相关变量。

### `//testing/test.gni` — 测试模板

```gn
import("//testing/test.gni")
```

提供 `rtc_test` 模板定义。

## 平台相关约定

### 跨平台源文件管理

```gn
rtc_source_set("platform_utils") {
  sources = [
    "utils_common.cc",
    "utils_common.h",
  ]

  if (is_win) {
    sources += [
      "utils_win.cc",
      "utils_win.h",
    ]
  }
  if (is_mac || is_ios) {
    sources += [
      "utils_apple.mm",
      "utils_apple.h",
    ]
  }
  if (is_linux || is_android) {
    sources += [
      "utils_linux.cc",
      "utils_linux.h",
    ]
  }
}
```

### 平台变量速查

| 变量 | 匹配平台 |
|------|---------|
| `is_win` | Windows |
| `is_mac` | macOS |
| `is_ios` | iOS |
| `is_android` | Android |
| `is_linux` | Linux（不含 Android） |
| `is_chromeos` | ChromeOS |
| `is_posix` | mac + linux + ios + android + chromeos |
| `build_with_chromium` | 在 Chromium 源码树中构建 |
| `build_with_mozilla` | Mozilla 定制构建 |

## 常见项目结构

```
project/
├── .gn                      # GN 根配置（buildconfig 指向）
├── BUILD.gn                 # 顶层 target + 公共 config
├── webrtc.gni               # WebRTC 变量声明（项目级覆盖）
├── tutor_engine.gni         # 项目自定义变量
├── build_overrides/         # 覆盖 Chromium 默认值
│   ├── build.gni
│   └── gtest.gni
├── workspace/
│   ├── module_a/
│   │   ├── BUILD.gn
│   │   ├── *.cc
│   │   └── *.h
│   └── module_b/
│       ├── BUILD.gn
│       ├── *.cc
│       └── *.h
├── third_party/
│   └── BUILD.gn              # 聚合所有 third_party 为 group
└── testing/
    └── BUILD.gn
```

## WebRTC 特有的 Config 链

WebRTC 默认 target 获得以下 config（通过 rtc_source_set 等模板自动添加）：

```
rtc_source_set / rtc_static_library
  → common_inherited_config   # 全局 defines（平台宏、特性开关）
  → common_config             # include_dirs、基础编译选项
  → :enable_libevent_config   # (条件) libevent 支持
  → remove_mainless_config    # 移除 Chromium main 函数依赖
```

**审查要点：**
- `remove_mainless_config` 在 `rtc_source_set` 等模板中自动添加，不要手动加
- 自定义 config 应通过 `configs +=` 追加，不要覆盖模板内置 config
- `common_inherited_config` 的 defines 变动会影响所有 WebRTC target

## 第三方库集成规范

```gn
# third_party/BUILD.gn
config("jsoncpp_config") {
  include_dirs = [ "jsoncpp/include" ]
}

source_set("jsoncpp") {
  sources = [ "jsoncpp/src/lib_json/json_reader.cpp", ... ]
  public_configs = [ ":jsoncpp_config" ]  # header path 传播给使用者
}

# 在 webrtc.gni 中声明路径变量
declare_args() {
  rtc_jsoncpp_dir = "//third_party:jsoncpp"
}

# 使用者
deps += [ rtc_jsoncpp_dir ]  # 通过变量引用，方便替换
```

## 链接错误排查速查

| 错误类型 | 常见 GN 原因 | 修复 |
|---------|-------------|------|
| `undefined symbol` | 缺少 deps 或使用了 `deps` 而非 `public_deps` | 补齐 deps，改用 public_deps |
| `duplicate symbol` | 两个 `complete_static_lib` 包含同一 source_set | 去掉 complete_static_lib 或分层 |
| `cannot find -lxxx` | `lib_dirs` / `libs` 路径错误 | 检查 conan lib 路径映射 |
| `header not found` | 缺少 deps 或 `include_dirs` config 未传播 | 用 public_configs 传播 include_dirs |
| `unknown function: rtc_source_set` | 未 import webrtc.gni | 添加 `import("//webrtc.gni")` |
