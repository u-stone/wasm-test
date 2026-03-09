# Wasm Concurrency Demo Workspace

这个仓库是一个用于对比 C++ -> WebAssembly 并发方案与调试方案的实验项目。

## 快速入口
1. 启动服务：`python .\server.py`
2. 隔离模式（带 COOP/COEP）：`http://localhost:8000/isolated/index.html`
3. 普通模式（不带 COOP/COEP）：`http://localhost:8000/plain/index.html`
4. 统一对比面板：`http://localhost:8000/isolated/compare.html`

## 构建
- 全量构建：
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_all.ps1 -DebugMode all
```

- 单模式构建：
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_all.ps1 -DebugMode release
powershell -ExecutionPolicy Bypass -File scripts/build_all.ps1 -DebugMode dwarf
powershell -ExecutionPolicy Bypass -File scripts/build_all.ps1 -DebugMode sourcemap
```

## 调试模式
页面支持三种 `debug` 模式，优先级如下：
1. URL 参数 `?debug=...`
2. `localStorage.wasmDebugMode`
3. 默认 `release`

可选值：
- `release`
- `dwarf`
- `sourcemap`

## 方案目录
- `demos/01-pthreads/`：Emscripten pthreads（共享内存）
- `demos/02-asyncify/`：Asyncify 协作式并发
- `demos/03-manual-workers/`：手工 Worker + 消息传递
- `demos/04-cpp20-coroutine/`：C++20 协程协作调度
- `demos/extra-interop/`：额外互操作示例

## 文档导航
- `docs/01-user-validation-guide.md`：用户验证与 UI 观察
- `docs/02-developer-code-reading-guide.md`：开发者读码路径
- `docs/03-debugging-wasm-js-guide.md`：Wasm + JS 调试方法
- `docs/04-technical-whitepaper.md`：技术白皮书（背景与方案全景）
- `requirements.txt`：Python 依赖声明（当前仅标准库）
