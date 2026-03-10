# C++ -> Wasm 与 JS 联合调试指南

## 1. 调试前准备
1. 构建包含调试信息的产物：
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_all.ps1 -DebugMode all
```
2. 启动服务：
```powershell
python .\server.py
```
3. 建议入口：
- `http://localhost:8000/isolated/index.html`（测试 pthreads 必用）

## 2. DWARF 与 Source Map 的区别
### DWARF (`debug=dwarf`)
- 调试信息在 wasm 内（或相关符号信息中）。
- 更接近原生 C/C++ 调试体验。
- 常用于现代浏览器 wasm 原生调试能力。

### Source Map (`debug=sourcemap`)
- 依赖 map 文件把编译后位置映射回源码。
- 对 JS glue 与源码映射更直观。

### release (`debug=release`)
- 用于对照性能与行为，不适合深度源码调试。

## 3. 在页面切换调试模式
方式 A（推荐）
- 在 `index.html` 的 `Debug Mode` 下拉直接选。

方式 B（URL）
- 手动加参数，例如：
  - `.../index.html?debug=dwarf`
  - `.../index.html?debug=sourcemap`

页面会据此加载 `output/<mode>/xxx.js`。

## 4. Chrome DevTools 调试步骤（通用）
1. 打开 demo 页面，按 F12。
2. 在 `Sources` 面板定位：
- C++ 源（映射后）
- 对应 JS glue 文件
3. 在关键点打断点：
- C++ 导出函数入口（如 `run_threads`）
- JS 调用点（如 `Module.ccall(...)`）
4. 执行后观察：
- 调用栈（Call Stack）
- 变量值
- console 输出顺序

## 5. 推荐断点位置
### pthreads
- `demos/01-pthreads/src/main.cc` 内 `run_threads`
- `demos/01-pthreads/web/index.html` 中 `runDemo` / `Module.ccall`

### asyncify
- `demos/02-asyncify/src/main.cc` 中 `run_asyncify_demo`
- 观察 step1/step2 与 run-end 时序

### manual workers
- `demos/03-manual-workers/web/main.js` 中 worker 创建和 onmessage
- `demos/03-manual-workers/web/task-worker.js` 中 `runJob`
- `demos/03-manual-workers/src/task.cc` 中 `run_heavy_task`

### coroutine
- `demos/04-cpp20-coroutine/src/main.cc` 中 `resume/yield` 路径

## 6. 验证 COOP/COEP 对调试和运行的影响
对同一 demo 做 A/B：
- A: `/isolated/...`
- B: `/plain/...`

观察：
- pthreads 能否正常运行
- 控制台 warning/错误变化
- compare 面板中的状态和耗时变化

## 7. 常见调试问题
### 看不到 C++ 源映射
- 先确认当前是 `debug=dwarf` 或 `debug=sourcemap`。
- 确认对应 `output/<mode>/` 文件已生成。

### 断点打不上
- 关闭缓存后刷新（DevTools Network 勾选 Disable cache）。
- 确认加载的是你期望模式（URL 参数 + 页面显示的 Debug mode）。

### dwarf 模式能看到 C++ 源码但断点打不上（01-pthreads 常见）
- 典型现象：`debug=dwarf` 且 `-O1 -g` 时，Sources 里能看到 `main.cc`，但某些行无法下断点或断点不命中。
- 根因：优化会改变源码行与最终 Wasm 指令的一一对应关系；浏览器只能在可停靠指令上绑定断点。
- 解决建议：
  - 需要高稳定断点时使用 `-O0 -g`（可单独定义为 debug 专用模式）。
  - 折中可尝试 `-Og -g` 或加 `-fno-inline`，减少优化对行映射的破坏。
  - 对比时保留 `release`/`dwarf` 双模式，避免把调试构建误当作性能结论。

### worker 内断点难以命中
- 在 `task-worker.js` 里先加 `debugger;`（临时）。
- 确保 worker 脚本 URL 带了正确 `debug` 参数。

### pthread 线程日志只看到 run_complete，看不到 thread_done
- 典型现象：`run_threads` 的线程内部日志在页面/compare 面板看不到，只看到函数末尾 `run_complete`。
- 根因：线程代码运行在 pthread worker，上下文与主页面 `window.console` 不同；主页面的 `console.log` hook 不能自动捕获 worker console。
- 修复策略（本项目已落地）：
  - 在线程内将日志代理回主线程，再由主线程 `console.log` 输出。
  - 实现位置：`demos/01-pthreads/src/main.cc` 中 `logOnMainThread(...)`。
  - 结果：`thread_done` 可被页面日志系统与 compare 面板统一采集。

### CMake 多 target 项目里有 `.wasm.map`，但 DevTools 看不到业务源码
- 典型现象：`sourcemap` 模式下能生成 `*.wasm.map`，但 DevTools 里只看到系统库源码，看不到自己项目的 `app/domain/core/platform` 源码。
- 常见根因：
  - 只有最终 wasm 可执行 target 在链接阶段添加了 `-gsource-map`。
  - 业务代码实际位于静态库 target 中。
  - 这些静态库在编译阶段没有统一带 `-g`，导致 object 文件缺少足够调试信息。
- 修复原则：
  - 编译阶段：对整个 CMake 工程统一下发调试编译参数。
  - 链接阶段：只对最终 wasm 目标添加 `-gsource-map` 和 `--source-map-base`。
- 本项目中的修复方式：
  - `demos/05-cmake-emcmake/cmake/WasmBuild.cmake` 中提供 `apply_wasm_compile_options(target)`。
  - `demos/05-cmake-emcmake/src/CMakeLists.txt` 中对 `cmake_core`、`cmake_platform`、`cmake_domain` 显式应用编译调试参数。
  - `sourcemap` 模式下，编译参数使用 `-O1 -g`，链接参数使用 `-O1`，最终目标再补 `-gsource-map`。
- 快速验证方法：
  - 打开 `demos/05-cmake-emcmake/output/sourcemap/*.wasm.map`。
  - 检查 `sources` 字段里是否出现 `src/app/*.cc`、`src/domain/*.cc`、`src/core/*.cc`、`src/platform/*.cc`。
  - 如果只有系统库源码而没有业务源码，通常就是“编译单元未统一带调试信息”的问题。

## 8. Worker DevTools 上下文切换（看 worker console）
1. 打开 DevTools（F12）。
2. 在 DevTools 顶部的执行上下文下拉框（通常显示 `top`）切到目标 worker。
3. 切到 `Console` 面板，此时输出即对应该 worker。
4. 若没看到 worker，先在 `Sources` 面板的 `Threads/Workers` 分组中选择目标 worker。
5. 选择 worker 后再回到 `Console`，查看对应上下文输出。
6. 对 pthreads 场景，建议同时观察主线程 console（汇总日志）与 worker console（线程局部细节）。

## 9. 建议调试流程
1. `release` 复现行为。
2. 切 `dwarf` 看 C++ 变量与流程。
3. 切 `sourcemap` 看映射与 glue 层。
4. 在 `isolated/plain` 两种模式下重复对比。
