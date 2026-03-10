# CMake 大型工程中的 Source Map Base 管理指南

## 1. 问题背景
当项目只有一个 Wasm 模块时，`--source-map-base` 可以直接写成固定 URL，例如：

```cmake
--source-map-base=http://localhost:8000/demos/05-cmake-emcmake/output/sourcemap/
```

但在大型项目中，这种做法很快会失控。常见原因包括：

1. 一个仓库中可能有几十到上百个 Wasm target。
2. 同一个 target 可能对应多个环境：本地、测试、预发、生产。
3. sourcemap 必须与具体构建版本严格对应，否则 DevTools 中源码、断点、行号都可能错位。
4. 调试资源往往不应与正式静态资源完全混放，需要独立调试域名或专用路径。

因此，`--source-map-base` 在大工程中不应按“每个工程手写完整 URL”的方式维护，而应作为统一构建与部署策略的一部分集中管理。

## 2. 核心结论
推荐把 `--source-map-base` 管理拆成 3 层：

1. 顶层规则：定义统一的 URL 拼接规则。
2. 工程元数据：每个 target 只提供项目名、模块名、构建版本等少量信息。
3. 环境注入：由本地脚本或 CI/CD 在构建时传入 host、environment、build id 等变量。

这样最终生成的 URL 不是人工维护的“长字符串”，而是统一规则自动拼接出来的结果。

## 3. 不推荐的做法

### 3.1 每个工程手写完整 URL
例如每个 `CMakeLists.txt` 都写：

```cmake
--source-map-base=https://debug.example.com/prod/game/render/
```

这种方式的问题是：

1. 配置重复，后续难统一修改。
2. 一旦域名、路径规范、版本策略变化，需要批量人工修改。
3. 多模块项目容易出现路径不一致、拼写错误、环境串用。

### 3.2 把 source map URL 写死为本地地址
例如永远使用 `http://localhost:8000/...`。

这种方式只适合最简单的 demo，不适合真实项目，因为测试与生产环境通常会使用不同的调试资源域名。

## 4. 推荐的统一管理模型

推荐使用以下变量：

```cmake
WASM_SOURCE_MAP_ROOT
WASM_ENV
WASM_PROJECT
WASM_BUILD_ID
WASM_SOURCE_MAP_TARGET_SEGMENT
```

它们的含义分别是：

1. `WASM_SOURCE_MAP_ROOT`：调试资源根地址，例如 `https://debug.example.com`。
2. `WASM_ENV`：环境名，例如 `dev`、`test`、`prod`。
3. `WASM_PROJECT`：逻辑项目名，例如 `battle-client`。
4. `WASM_BUILD_ID`：构建版本、构建号或 commit SHA。
5. `WASM_SOURCE_MAP_TARGET_SEGMENT`：当前 target 的路径片段，例如 `render`、`physics`、`ai`。

最终可以统一拼接为：

```text
<root>/<env>/<project>/<target>/<build-id>/
```

例如：

```text
https://debug.example.com/prod/battle-client/render/1.3.27+abc123/
```

这种结构的优点是：

1. 目录层次清晰。
2. 支持多 target 并存。
3. 支持多版本并存。
4. 出问题时更容易回溯具体构建。

## 5. 推荐的 CMake 封装方式

### 5.1 在公共 cmake 模块中集中处理
不要让每个 `CMakeLists.txt` 自己拼 URL。推荐在顶层公共模块中定义函数，例如：

```cmake
function(configure_wasm_sourcemap target)
  if(NOT WASM_DEBUG_MODE STREQUAL "sourcemap")
    return()
  endif()

  set(base "${WASM_SOURCE_MAP_ROOT}/${WASM_ENV}/${WASM_PROJECT}/${target}/${WASM_BUILD_ID}/")
  target_link_options(${target} PRIVATE
    "-gsource-map"
    "--source-map-base=${base}"
  )
endfunction()
```

然后每个 target 只需要调用：

```cmake
configure_wasm_sourcemap(render)
configure_wasm_sourcemap(physics)
configure_wasm_sourcemap(ai)
```

这样所有 target 的 sourcemap 规则都被统一管理。

### 5.2 compile 与 link 参数分离
`-gsource-map` 与 `--source-map-base` 本质是链接阶段参数，推荐只放在 `target_link_options(...)` 中。

例如：

```cmake
target_compile_options(my_target PRIVATE -O1)
target_link_options(my_target PRIVATE -O1 -gsource-map "--source-map-base=${base}")
```

这比把所有参数都混在一个变量里更清晰，也更符合大工程维护习惯。

## 6. 由 CI/CD 注入，而不是写死在源码里
对于大型项目，推荐把以下值交给 CI/CD 传入：

1. `WASM_SOURCE_MAP_ROOT`
2. `WASM_ENV`
3. `WASM_PROJECT`
4. `WASM_BUILD_ID`

例如流水线中执行：

```powershell
emcmake cmake -S . -B build/sourcemap \
  -DWASM_DEBUG_MODE=sourcemap \
  -DWASM_SOURCE_MAP_ROOT=https://debug.example.com \
  -DWASM_ENV=prod \
  -DWASM_PROJECT=battle-client \
  -DWASM_BUILD_ID=abc123
```

这样本地开发、测试环境、生产环境都可以复用同一套 `CMakeLists.txt`，区别只在外部传参。

## 7. 为什么一定要带版本号
大型项目里最危险的问题不是“没有 sourcemap”，而是“加载了错误版本的 sourcemap”。

如果页面加载的是新版 wasm，但 sourcemap 指向旧版源码，通常会出现：

1. Sources 里能打开源码。
2. 断点能下，但命中位置偏移。
3. Call Stack 与变量信息不可信。

因此建议把 `WASM_BUILD_ID` 纳入 `--source-map-base` 路径层级，确保每次构建都能唯一对应一套源码映射。

## 8. 调试资源与正式资源分离
在真实项目中，推荐将 sourcemap 和正式运行资源分开托管。例如：

1. 正式资源：`https://cdn.example.com/game/...`
2. 调试资源：`https://debug.example.com/game/...`

好处包括：

1. 可以只对内部网络或特定账号开放调试资源。
2. 可以单独配置缓存策略。
3. 可以避免把源码映射暴露到公开 CDN。

## 9. 本仓库中的 demo 如何对应到大型工程实践
本仓库中的 `demos/05-cmake-emcmake/` 已经升级为模板化实现，当前使用以下变量：

```cmake
WASM_SOURCE_MAP_ROOT
WASM_ENV
WASM_PROJECT
WASM_BUILD_ID
WASM_SOURCE_MAP_TARGET_SEGMENT
```

并通过公共模块：

```cmake
cmake/WasmSourceMap.cmake
cmake/WasmBuild.cmake
```

来统一拼接与注入 `--source-map-base`，并把调试模式、编译参数、链接参数、导出函数配置统一封装到 `configure_wasm_build(...)`。当前 demo 的默认值被设计为与本地目录结构一致：

```text
http://localhost:8000/demos/05-cmake-emcmake/output/sourcemap/
```

其对应关系为：

1. `WASM_SOURCE_MAP_ROOT=http://localhost:8000`
2. `WASM_ENV=demos`
3. `WASM_PROJECT=05-cmake-emcmake`
4. `WASM_SOURCE_MAP_TARGET_SEGMENT=output`
5. `WASM_BUILD_ID=sourcemap`

这个 demo 现在可以直接用来演示四件事：

1. `--source-map-base` 应在 CMake 内部统一管理。
2. sourcemap URL 应由规则和元数据拼接，而不是手写长 URL。
3. 真实项目中可以通过 CI/CD 覆盖这些变量而不改源码。
4. 同一个公共模板模块可以服务多个 Wasm target。

## 9.1 当前模板的使用方式
本 demo 当前的顶层 `CMakeLists.txt` 已经收敛为声明式调用：

```cmake
configure_wasm_build(
  cmake_demo
  OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/output/${WASM_DEBUG_MODE}"
  SOURCE_MAP_TARGET_SEGMENT "${WASM_SOURCE_MAP_TARGET_SEGMENT}"
  EXPORTED_FUNCTIONS "[\"_run_cmake_demo\"]"
  EXPORTED_RUNTIME_METHODS "[\"ccall\"]"
)
```

这意味着真实项目里：

1. 顶层 CMake 只描述目标需要什么。
2. 目标输出目录、后缀、导出函数等目标属性也由公共模块负责。
3. 具体如何根据 `WASM_DEBUG_MODE` 选择 `-O2 / -g / -gsource-map`，由公共模块负责。
4. 具体如何拼接 `--source-map-base`，也由公共模块负责。
5. 多个 target 可以复用同一套模板函数，而不需要复制粘贴配置块。

这比在每个工程里手写一组 if/else 更接近真实大项目的维护方式。

## 10. 推荐落地方案
对于大型项目，建议按以下优先级落地：

1. 先统一 sourcemap URL 规则，不再允许各工程手写完整地址。
2. 再把规则收口到公共 CMake 模块中，按 target 自动生成。
3. 最后由 CI/CD 注入环境与版本元数据，实现多环境与多版本统一管理。

这样做的最终收益是：

1. 配置集中，维护成本低。
2. 多 target 与多版本可追溯。
3. DevTools 中的源码映射更稳定、可复现、可排障。

## 11. 为什么不加 --source-map-base 也可能看到源码
这是一个常见误区。`--source-map-base` 不是“是否开启源码调试”的开关，而是“浏览器用哪个 URL 基准去理解 sourcemap 资源”的配置。

在以下情况下，即使不加 `--source-map-base`，DevTools 也可能仍然能看到 C++ 源码：

1. `*.wasm`、`*.wasm.map` 与源码引用的相对路径刚好可以被浏览器推导出来。
2. `sources` 字段里的相对路径相对于 map 文件位置是可达的。
3. 浏览器当前页面 URL 与静态资源目录结构刚好一致。

因此“不加也能调试”并不说明该参数没有价值，只说明当前 demo 或部署结构恰好足够简单，浏览器可以自行推导。

## 12. 为什么加了 --source-map-base 后 Sources > Page 的树会变化
DevTools 不是按磁盘路径组织文件，而是按浏览器理解出来的 URL 归属来组织文件。

1. 不加 `--source-map-base` 时，DevTools 通常按 `*.wasm` 或 `*.wasm.map` 的相对位置去推导源码归属。
2. 加上 `--source-map-base` 后，DevTools 会优先按你显式提供的 URL 基准组织源码。

所以常见现象是：

1. 源码仍然能打开，但目录树位置变了。
2. `Sources > Page` 里的路径更接近你部署时的 URL 结构。
3. 多 target、多环境时，源码归属更稳定，不容易混在一起。

## 13. 本仓库修复过的一个真实问题：为什么 map 文件存在，但 DevTools 里看不到业务源码
这个仓库的 `05-cmake-emcmake` 在模板演进过程中出现过一个典型问题：

1. `-gsource-map` 只加到了最终可执行 target 的链接阶段。
2. 业务代码位于 `cmake_core`、`cmake_domain`、`cmake_platform` 等静态库中。
3. 这些库在编译时没有统一带 `-g`，导致 object 文件里缺少足够的调试信息。

结果就是：

1. `cmake_demo.wasm.map` 文件会生成。
2. DevTools 中可能能看到系统库源码。
3. 但看不到项目自己的 `app/domain/core/platform` 源码，或者源码不完整。

修复方式是：

1. 对整个 CMake 工程统一下发编译调试参数，而不是只给最终可执行 target 设置。
2. 在 `sourcemap` 模式下，所有编译单元都使用 `-O1 -g`。
3. 最终链接目标再单独添加 `-gsource-map` 与 `--source-map-base`。

当前模板中的 `WasmBuild.cmake` 已按这个原则实现：

1. `apply_wasm_compile_options(target)` 负责按 target 显式添加编译参数。
2. `configure_wasm_build(...)` 负责给最终 Wasm target 统一配置目标属性、链接参数与 sourcemap 规则。

这也是大型项目里更稳妥的做法：

1. 编译调试信息是全工程问题。
2. `--source-map-base` 是最终链接与部署映射问题。
3. 两者不能混为一谈。