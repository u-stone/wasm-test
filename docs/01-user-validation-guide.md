# 用户验证与演示指南

## 1. 目标
本指南面向使用者，帮助你快速验证本项目中的 4 种并发/多线程方案，并在 UI 上观察差异。

## 2. 启动步骤
### 2.0 Python 虚拟环境（可选但推荐）
本项目当前的 Python 脚本只依赖标准库，不装第三方包也能运行；但建议使用 `.venv` 统一团队环境。

Windows PowerShell:
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

macOS/Linux (bash/zsh):
```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

说明：`requirements.txt` 当前为空依赖声明（仅注释），表示无第三方 Python 包。

1. 编译所有模式产物（包含 release / dwarf / sourcemap）：
```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_all.ps1 -DebugMode all
```
2. 启动本地服务器：
```powershell
python .\server.py
```
3. 打开首页：
- 隔离模式（带 COOP/COEP）: `http://localhost:8000/isolated/index.html`
- 普通模式（不带 COOP/COEP）: `http://localhost:8000/plain/index.html`

### 2.1 外部工具依赖
除 Python 外，本项目还依赖以下外部工具：

1. `Emscripten SDK (emsdk)`：用于 `em++` 编译 C++ -> Wasm。
2. 可用浏览器：建议最新版 Chrome/Edge（用于 Wasm 与 DevTools 调试）。

可通过以下命令快速检查：
```powershell
em++ --version
python --version
```

## 3. UI 入口说明
在 `index.html` 顶部有两个按钮：
- `隔离模式打开`
- `普通模式打开`

同页还有 `Debug Mode` 下拉：
- `release`：优化构建，体积更小
- `dwarf`：Wasm 内嵌 DWARF 调试信息
- `sourcemap`：生成 Source Map，便于源码映射

所有 demo 链接和统一面板链接会自动带上当前 `debug` 参数。

## 4. 统一对比面板怎么用
打开：`http://localhost:8000/isolated/compare.html`（或 plain 版本）。

面板功能：
- `Run All`：同时触发四个方案
- `Run This`：仅触发某一方案
- 每个卡片显示：`Status`、`Last`（最近耗时）、`Runs`
- 下方 `Unified Event Log` 聚合四个方案的日志

## 5. 四种方案预期现象
### 01 - Pthreads (SharedArrayBuffer)
- 在 `isolated` 下应正常运行并输出线程完成日志。
- 在 `plain` 下通常会遇到 SharedArrayBuffer 不可用（或线程能力受限）。

### 02 - Asyncify
- 日志会出现类似 step1 -> step2 的分段执行。
- 体现“协作式让出控制权”，不是真并行。

### 03 - Manual Web Workers
- 每个 worker 输出单独完成日志，最终汇总总耗时与 combined 结果。
- 体现消息传递模型，不依赖 pthreads。

### 04 - C++20 Coroutine
- 日志会交替出现 task yield 结果。
- 体现单线程下协作式调度。

## 6. 推荐验证矩阵
建议最少跑 2x3 组：
- 模式：`isolated` / `plain`
- 调试：`release` / `dwarf` / `sourcemap`

重点观察：
1. pthreads 在两种服务器模式下行为差异。
2. 三种调试构建是否都可正常加载与运行。
3. 对比面板耗时与日志是否稳定可复现。

## 7. 常见问题
### 页面白屏或 404
先确认运行过 `build_all.ps1 -DebugMode all`，并检查是否使用了正确 URL 前缀（`/isolated/` 或 `/plain/`）。

### pthreads 不工作
确认使用 `isolated` 路径访问，且浏览器支持 `SharedArrayBuffer`。

### 切了 Debug Mode 但似乎没变化
清理浏览器缓存后重试，并确认 URL 中包含 `?debug=...`。
