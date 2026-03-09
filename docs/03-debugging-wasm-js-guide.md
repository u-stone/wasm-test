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

### worker 内断点难以命中
- 在 `task-worker.js` 里先加 `debugger;`（临时）。
- 确保 worker 脚本 URL 带了正确 `debug` 参数。

## 8. 建议调试流程
1. `release` 复现行为。
2. 切 `dwarf` 看 C++ 变量与流程。
3. 切 `sourcemap` 看映射与 glue 层。
4. 在 `isolated/plain` 两种模式下重复对比。
