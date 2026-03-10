# CMake Wasm Helper Modules Developer Guide

这份文档面向维护 `demos/05-cmake-emcmake/cmake/WasmBuild.cmake` 与 `demos/05-cmake-emcmake/cmake/WasmSourceMap.cmake` 的开发者，重点说明这两个模块的职责边界、接入方式、参数约定与常见使用模式。

## 1. 模块职责

这两个模块是分层设计的。

1. `WasmBuild.cmake`
   - 负责 `WASM_DEBUG_MODE` 对应的编译参数与链接参数。
   - 负责把编译参数应用到指定 target。
   - 负责给最终 Wasm target 设置输出目录、输出后缀、导出函数、导出运行时方法。
   - 负责在需要时调用 sourcemap 模块。

2. `WasmSourceMap.cmake`
   - 负责把 `WASM_SOURCE_MAP_ROOT`、`WASM_ENV`、`WASM_PROJECT`、`WASM_BUILD_ID`、`target_segment` 组合成统一的 `--source-map-base`。
   - 负责只在 `sourcemap` 模式下给最终 target 注入 `-gsource-map` 与 `--source-map-base=...`。

可以把它们理解为：

1. `WasmBuild.cmake` 决定“怎么构建 Wasm target”。
2. `WasmSourceMap.cmake` 决定“sourcemap URL 应该长什么样”。

## 2. 为什么拆成两个模块

拆分的核心目的是把“构建参数问题”和“部署 URL 规则问题”分开。

1. `-O2 / -O0 -g / -O1 -g` 属于编译与链接策略。
2. `--source-map-base` 属于浏览器如何理解 sourcemap 资源 URL 的策略。
3. 二者虽然都在 Wasm 调试链路里，但不是同一类问题。

这样拆分后有几个好处：

1. `WasmBuild.cmake` 可以在别的项目里单独复用，即使对方不需要统一 sourcemap URL。
2. `WasmSourceMap.cmake` 可以独立演进 URL 模板，而不影响编译参数逻辑。
3. 出现调试问题时，更容易判断故障是在“编译单元没有调试信息”还是“浏览器 sourcemap URL 归属错误”。

## 3. 接入方式

顶层 `CMakeLists.txt` 的典型接入方式如下：

```cmake
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(WasmBuild)

set(WASM_DEBUG_MODE "sourcemap" CACHE STRING "release, dwarf, sourcemap")
set(WASM_SOURCE_MAP_ROOT "http://localhost:8000" CACHE STRING "Base URL used by source maps")
set(WASM_ENV "demos" CACHE STRING "Top-level environment segment used in source map URLs")
set(WASM_PROJECT "05-cmake-emcmake" CACHE STRING "Project segment used in source map URLs")
set(WASM_BUILD_ID "sourcemap" CACHE STRING "Build identifier used in source map URLs")
set(WASM_SOURCE_MAP_TARGET_SEGMENT "output" CACHE STRING "Target-specific path segment used in sourcemap URLs")

print_wasm_build_summary()
add_subdirectory(src)

configure_wasm_build(
  cmake_demo
  OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/output/${WASM_DEBUG_MODE}"
  SOURCE_MAP_TARGET_SEGMENT "${WASM_SOURCE_MAP_TARGET_SEGMENT}"
  EXPORTED_FUNCTIONS "[\"_run_cmake_demo\"]"
  EXPORTED_RUNTIME_METHODS "[\"ccall\"]"
)
```

子目录 `src/CMakeLists.txt` 中的典型写法如下：

```cmake
add_library(cmake_core STATIC core/accumulator.cc)
target_include_directories(cmake_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
apply_wasm_compile_options(cmake_core)

add_library(cmake_domain STATIC domain/simulation.cc)
target_link_libraries(cmake_domain PUBLIC cmake_core)
apply_wasm_compile_options(cmake_domain)

add_executable(cmake_demo app/main.cc)
target_link_libraries(cmake_demo PRIVATE cmake_domain)
```

推荐约定是：

1. 静态库 target 用 `apply_wasm_compile_options(target)`。
2. 最终 Wasm 可执行 target 用 `configure_wasm_build(target ...)`。

## 4. `WasmBuild.cmake` API 说明

### 4.1 `get_wasm_compile_flags(out_var)`

根据 `WASM_DEBUG_MODE` 返回编译参数。

当前规则：

1. `release` -> `-O2`
2. `dwarf` -> `-O0 -g`
3. `sourcemap` -> `-O1 -g`

设计原因：

1. `sourcemap` 模式下 map 在链接阶段生成，但对象文件仍然需要调试信息。
2. 如果静态库编译阶段没有 `-g`，最终 `*.wasm.map` 很容易只剩系统库源码而没有业务源码。

### 4.2 `get_wasm_link_flags(out_var)`

根据 `WASM_DEBUG_MODE` 返回链接参数。

当前规则：

1. `release` -> `-O2`
2. `dwarf` -> `-O0 -g`
3. `sourcemap` -> `-O1`

注意：

1. `sourcemap` 模式下，这里故意不直接返回 `-gsource-map`。
2. `-gsource-map` 由 `WasmSourceMap.cmake` 在最终 target 层面注入。

### 4.3 `apply_wasm_compile_options(target)`

把当前模式对应的编译参数应用到一个已存在的 target。

适用对象：

1. `STATIC` 库
2. `OBJECT` 库
3. 需要参与最终 Wasm 链接且必须保留调试信息的其他 target

不建议把它当作“全局目录级配置”的替代品。这个函数的目的就是显式、精准地控制 target。

### 4.4 `configure_wasm_build(target ...)`

这是最终 Wasm target 的统一入口。

支持的参数如下：

1. `OUTPUT_DIRECTORY`
   - 最终产物输出目录。
   - 会映射到 `RUNTIME_OUTPUT_DIRECTORY`。

2. `TARGET_SUFFIX`
   - 最终产物后缀。
   - 默认是 `.js`。
   - 目前这个 demo 没有覆盖它，但保留了扩展点。

3. `SOURCE_MAP_TARGET_SEGMENT`
   - sourcemap URL 中的 target 路径段。
   - 会传给 `configure_wasm_sourcemap(...)`。

4. `EXPORTED_FUNCTIONS`
   - 透传为 `-sEXPORTED_FUNCTIONS=...`。
   - 需要使用 Emscripten 的 JSON 数组字符串格式，例如 `["_run_cmake_demo"]`。

5. `EXPORTED_RUNTIME_METHODS`
   - 透传为 `-sEXPORTED_RUNTIME_METHODS=...`。
   - 例如 `["ccall"]`。

它会完成以下事情：

1. 检查 target 是否存在。
2. 设置输出后缀与输出目录。
3. 对最终 target 应用编译参数。
4. 对最终 target 应用链接参数。
5. 按需添加导出函数与 runtime methods。
6. 在 `sourcemap` 模式下调用 `configure_wasm_sourcemap(...)`。

### 4.5 `print_wasm_build_summary()`

在配置阶段打印当前构建摘要，方便快速确认模式是否正确。

推荐在顶层 `CMakeLists.txt` 中尽早调用一次，这样能在 `cmake -S . -B ...` 阶段直接看到：

1. `WASM_DEBUG_MODE`
2. 编译参数
3. 链接参数
4. sourcemap 相关变量

## 5. `WasmSourceMap.cmake` API 说明

### 5.1 `wasm_compute_source_map_base(out_var, target_segment)`

这个函数会把以下变量拼接成最终 URL：

1. `WASM_SOURCE_MAP_ROOT`
2. `WASM_ENV`
3. `WASM_PROJECT`
4. `target_segment`
5. `WASM_BUILD_ID`

例如：

1. `WASM_SOURCE_MAP_ROOT=http://localhost:8000`
2. `WASM_ENV=demos`
3. `WASM_PROJECT=05-cmake-emcmake`
4. `target_segment=output`
5. `WASM_BUILD_ID=sourcemap`

生成结果是：

```text
http://localhost:8000/demos/05-cmake-emcmake/output/sourcemap/
```

模块内部会自动去掉多余的前后斜杠，避免出现双斜杠路径。

### 5.2 `configure_wasm_sourcemap(target, target_segment)`

这是 sourcemap 的最终注入函数。

行为如下：

1. 如果当前不是 `sourcemap` 模式，直接返回，不做任何事。
2. 如果 `WASM_SOURCE_MAP_ROOT` 为空，则打印禁用信息并返回。
3. 否则给 target 注入：
   - `-gsource-map`
   - `--source-map-base=<computed-url>`
4. 同时打印 `WASM_SOURCE_MAP_BASE(target)=...` 便于核对。

## 6. 变量约定

这两个模块依赖的关键变量如下。

1. `WASM_DEBUG_MODE`
   - 必填。
   - 当前支持：`release`、`dwarf`、`sourcemap`。

2. `WASM_SOURCE_MAP_ROOT`
   - 可选。
   - 为空时表示不启用 `--source-map-base`。

3. `WASM_ENV`
   - 可选。
   - 用于表示环境或顶层业务域，例如 `demos`、`staging`、`prod`。

4. `WASM_PROJECT`
   - 可选。
   - 用于表示项目路径段。

5. `WASM_BUILD_ID`
   - 可选。
   - 用于表示调试模式、版本号或构建编号。

6. `WASM_SOURCE_MAP_TARGET_SEGMENT`
   - 可选。
   - 用于表示产物目录段，例如 `output`。

推荐把这些变量都定义成 `CACHE STRING`，这样：

1. 本地开发可以直接 `-D...` 覆盖。
2. CI/CD 也可以从外部注入。

## 7. 推荐使用模式

### 7.1 单个 Wasm target

如果工程里只有一个最终 Wasm target：

1. 所有参与链接的静态库都调用 `apply_wasm_compile_options(...)`。
2. 最终 target 调用一次 `configure_wasm_build(...)`。

### 7.2 多个 Wasm target

如果工程里有多个最终 Wasm target：

1. 所有共享业务库仍然单独调用 `apply_wasm_compile_options(...)`。
2. 每个最终 target 分别调用一次 `configure_wasm_build(...)`。
3. 每个 target 可以共用同一个 `SOURCE_MAP_TARGET_SEGMENT`，也可以按需要覆盖。

### 7.3 CI/CD 构建

推荐从外部注入以下变量：

1. `WASM_DEBUG_MODE`
2. `WASM_SOURCE_MAP_ROOT`
3. `WASM_ENV`
4. `WASM_PROJECT`
5. `WASM_BUILD_ID`

这样可以让同一套模板同时服务：

1. 本地开发调试
2. 测试环境部署
3. 生产构建归档

## 8. 常见误用

### 8.1 只给最终 target 配 `configure_wasm_build(...)`，不给静态库配 `apply_wasm_compile_options(...)`

这是最常见的问题。

结果通常是：

1. `.wasm.map` 文件存在。
2. 浏览器里能看到部分系统库源码。
3. 业务源码不完整，甚至完全不可见。

### 8.2 把 `--source-map-base` 当成“开启调试”的总开关

不是。

1. 是否能看到源码，首先取决于编译单元有没有调试信息。
2. `--source-map-base` 解决的是浏览器如何解析与归属 sourcemap URL。

### 8.3 把 target 级接口退回成目录级全局设置

不建议这么做。

1. 目录级设置在多 target 工程里很容易失控。
2. 精准控制 target 时，不容易看清到底哪些目标带了调试参数。
3. 当前模板已经明确选择“target 级显式应用”的方向。

## 9. 排障建议

当 DevTools 中看不到业务源码时，按下面顺序检查：

1. `WASM_DEBUG_MODE` 是否真的是 `sourcemap`。
2. 静态库 target 是否调用了 `apply_wasm_compile_options(...)`。
3. 最终 target 是否调用了 `configure_wasm_build(...)`。
4. `*.wasm.map` 是否实际生成。
5. `*.wasm.map` 中的 `sources` 字段里是否包含 `src/app`、`src/domain`、`src/core`、`src/platform`。
6. `WASM_SOURCE_MAP_BASE(target)=...` 打印出的 URL 是否与静态服务路径一致。

## 10. 当前仓库中的参考位置

可以直接参考以下文件：

1. `demos/05-cmake-emcmake/CMakeLists.txt`
2. `demos/05-cmake-emcmake/src/CMakeLists.txt`
3. `demos/05-cmake-emcmake/build.ps1`
4. `docs/05-cmake-sourcemap-base-guide.md`

如果后续要继续工程化，优先级最高的方向通常是：

1. 为更多 target 抽象统一的导出函数预设。
2. 把构建后 smoke check 接入 CI。
3. 保持文档与 `WasmBuild.cmake` / `WasmSourceMap.cmake` 的参数定义同步更新。