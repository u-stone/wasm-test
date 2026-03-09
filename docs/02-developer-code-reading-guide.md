# 开发者读码指南

## 1. 项目结构
```text
.
|- index.html
|- compare.html
|- server.py
|- scripts/
|  |- build_all.ps1
|- demos/
|  |- 01-pthreads/
|  |- 02-asyncify/
|  |- 03-manual-workers/
|  |- 04-cpp20-coroutine/
|  |- extra-interop/
```

每个 demo 目录基本一致：
- `src/` C++ 源码
- `web/` 页面与 JS 交互代码
- `output/<mode>/` 构建产物（release/dwarf/sourcemap）
- `build.ps1` 单 demo 构建脚本

## 2. 推荐阅读顺序
1. `server.py`
- 理解 `/isolated/` 与 `/plain/` 双模式如何切换 COOP/COEP。

2. `index.html` 与 `compare.html`
- 理解 debug 模式如何通过 `localStorage + query` 下发到各 demo。
- 理解统一面板如何通过 `postMessage` 收集状态与日志。

3. 四个核心 demo
- `demos/01-pthreads/src/main.cc`
- `demos/02-asyncify/src/main.cc`
- `demos/03-manual-workers/src/task.cc`
- `demos/04-cpp20-coroutine/src/main.cc`

4. 对应 web glue
- `demos/*/web/index.html`
- `demos/03-manual-workers/web/main.js`
- `demos/03-manual-workers/web/task-worker.js`

## 3. 每个方案的关键点
### 01 pthreads
- C++ 使用 `std::thread`。
- Emscripten 编译参数包含 `-pthread` 与 `PTHREAD_POOL_SIZE`。
- 依赖 `SharedArrayBuffer`，必须在 `isolated` 下验证。

### 02 asyncify
- 通过 `emscripten_sleep` 等机制模拟协作式“暂停/恢复”。
- 不是并行，适合展示异步让渡。

### 03 manual workers
- JS 层显式创建 `Worker`。
- 每个 worker 加载独立 wasm 实例并通过 `postMessage` 通信。

### 04 coroutine
- C++20 协程建模任务切换。
- 单线程下通过 `resume/yield` 展示调度。

## 4. 调试模式如何贯穿全项目
1. 构建阶段：
- `build.ps1 -DebugMode release|dwarf|sourcemap|all`

2. 运行阶段：
- 页面读取 `?debug=` 或 `localStorage.wasmDebugMode`
- 动态加载 `output/<mode>/*.js`

3. 对比面板阶段：
- `compare.html` 将当前 debug mode 附加到每个 iframe URL。

## 5. 扩展一个新 demo 的最小步骤
1. 新建 `demos/xx-your-demo/{src,web,output}`。
2. 写 `build.ps1`，支持 `-DebugMode` 参数并产出到 `output/<mode>/`。
3. 页面按 `debug` 参数动态加载脚本。
4. 若要接入 `compare.html`，实现 `postMessage` 事件：
- `ready`
- `run-start`
- `log`
- `run-end`

## 6. 开发约定（建议）
- C++ 源码尽量聚焦算法/线程逻辑。
- 页面仅负责加载、触发、日志。
- 所有路径保持相对且可在 `/isolated/` 和 `/plain/` 下工作。
