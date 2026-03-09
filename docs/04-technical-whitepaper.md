# WebAssembly 并发与调试体系技术白皮书

## 摘要
本文档系统描述本项目中 WebAssembly 并发与调试体系的技术背景、设计动机、实现路径与工程权衡。项目核心目标是：在浏览器环境下，构建可对比、可调试、可扩展的 C++ -> Wasm 技术验证平台，以支持以下关键能力：

1. 同一业务语义下的多种并发/多线程方案对照。
2. 同一页面内的统一观测（统一对比面板）。
3. 同一代码库下的多调试产物（release / DWARF / Source Map）。
4. 同一服务实例中可切换的安全隔离模式（COOP/COEP on/off）。

该平台既面向技术验证，也面向教学、团队评审与方案选型。

## 1. 背景与问题定义

### 1.1 浏览器并发模型与原生线程模型的错位
现代浏览器执行 JavaScript 时，天然采用“事件循环 + Worker 隔离内存”的模型。Web Worker 默认不共享可变内存，线程间主要通过消息传递。与此同时，C/C++ 生态中的 `std::thread` 与 pthread 语义依赖共享内存地址空间。

因此，C++ 编译到 Wasm 之后，要在浏览器中“保留”共享内存线程模型，必须解决两个核心问题：

1. 跨 Worker 的共享内存如何建立。
2. 共享内存的安全边界如何满足浏览器策略要求。

### 1.2 SharedArrayBuffer 的安全门槛
在浏览器中，`SharedArrayBuffer` 受 Spectre 类攻击防护策略影响，通常需要跨源隔离（cross-origin isolation）才能启用。跨源隔离依赖以下 HTTP 响应头：

- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Embedder-Policy: require-corp`

这意味着“多线程 Wasm 能否运行”不仅是编译问题，也是部署与服务配置问题。

### 1.3 工程目标
为避免单点论证偏差，本项目采用“多方案并行 + 同场景对比”方式，目标包括：

1. 方案可比性：四种并发策略在同一工程下可重复运行。
2. 可观测性：日志、耗时、状态统一采集。
3. 可解释性：从源码到构建产物到运行路径可追踪。
4. 可调试性：支持 DWARF 与 Source Map 两条调试链路。

## 2. 系统架构概览

### 2.1 目录分层
项目采用“按 demo 切分 + 每个 demo 自包含”的结构：

- `demos/<demo-name>/src`：C++ 源码。
- `demos/<demo-name>/web`：页面入口与 JS 控制层。
- `demos/<demo-name>/output/<mode>`：构建产物，按调试模式分层。
- `demos/<demo-name>/build.ps1`：单 demo 构建脚本。
- `scripts/build_all.ps1`：全量构建编排。

### 2.2 运行形态
平台提供两类入口：

1. 单 demo 页面（面向深入验证）。
2. `compare.html` 统一对比面板（面向横向对照）。

统一对比面板通过 `iframe + postMessage` 采集四个 demo 的 `ready / run-start / log / run-end` 事件，形成统一观测视图。

### 2.3 服务层策略
`server.py` 同时暴露两种虚拟根路径：

- `/isolated/*`：发送 COOP/COEP（可运行 pthreads 共享内存方案）。
- `/plain/*`：不发送 COOP/COEP（用于对比“未隔离”行为）。

该设计实现了“同服务、同代码、双安全策略”的 A/B 演示能力。

## 3. 四种并发/多线程方案

本项目重点对比以下四种技术路径。

### 3.1 方案 A：Emscripten pthreads（共享内存真并行）

#### 原理
Emscripten 将 C++ `std::thread` 映射为浏览器 Worker，并通过 `SharedArrayBuffer` 提供共享线性内存，结合原子操作模拟原生线程同步语义。

#### 关键特征
- 优势：与原生 C++ 线程模型最接近，迁移成本低。
- 限制：强依赖跨源隔离头；部署策略要求更高。
- 适用：CPU 密集并行、已有 pthread 代码复用。

#### 在本项目中的体现
- 源码：`demos/01-pthreads/src/main.cc`
- 页面：`demos/01-pthreads/web/index.html`
- 构建：`demos/01-pthreads/build.ps1`

### 3.2 方案 B：Asyncify（协作式并发，非并行）

#### 原理
Asyncify 将调用栈可中断化，在“逻辑上阻塞”的位置做暂停/恢复，形成协作式并发效果。其本质不是多核并行，而是单线程流程切片。

#### 关键特征
- 优势：无需 SharedArrayBuffer 与隔离头。
- 限制：额外运行时开销；并非真并行。
- 适用：异步流程整形、阻塞式 API 迁移演示。

#### 在本项目中的体现
- 源码：`demos/02-asyncify/src/main.cc`
- 页面：`demos/02-asyncify/web/index.html`
- 构建：`demos/02-asyncify/build.ps1`

### 3.3 方案 C：Manual Web Workers（消息传递并行）

#### 原理
不使用 pthread 语义，由 JS 层显式管理 Worker。每个 Worker 各自加载 Wasm 实例，任务通过消息传递分发与汇总。

#### 关键特征
- 优势：部署限制更低，架构显式清晰。
- 限制：共享状态管理成本高，跨实例数据同步复杂。
- 适用：天然可分片任务、批处理并行。

#### 在本项目中的体现
- 核心计算：`demos/03-manual-workers/src/task.cc`
- 主线程控制：`demos/03-manual-workers/web/main.js`
- Worker 启动：`demos/03-manual-workers/web/task-worker.js`

### 3.4 方案 D：C++20 Coroutine（单线程协作调度）

#### 原理
使用 C++20 协程状态机能力，通过 `resume/yield` 进行任务交错推进，在单线程内实现“并发感”。

#### 关键特征
- 优势：逻辑表达力强，状态管理可控。
- 限制：不提供并行吞吐；更偏编排而非算力扩展。
- 适用：流程编排、状态机式任务协作。

#### 在本项目中的体现
- 源码：`demos/04-cpp20-coroutine/src/main.cc`
- 页面：`demos/04-cpp20-coroutine/web/index.html`
- 构建：`demos/04-cpp20-coroutine/build.ps1`

## 4. 调试体系设计（DWARF 与 Source Map）

### 4.1 问题背景
Wasm 调试通常面临“源码语义丢失”与“栈信息不直观”问题。仅有 release 构建时，定位 C++ 源码上下文较困难。

### 4.2 三类构建模式
本项目统一产出三类构建：

- `release`：优化为主，体积与性能优先。
- `dwarf`：包含 DWARF 调试信息，优先原生 C++ 调试体验。
- `sourcemap`：生成映射文件，强调源码映射可读性。

产物目录统一为：`output/<mode>/`。

### 4.3 如何生成 DWARF 与 Source Map 产物

先给一个结论：
1. `dwarf` 模式通过 `-g` 把 C/C++ 源码、行号、符号等调试元数据写入 Wasm 调试信息。
2. `sourcemap` 模式通过 `-gsource-map` 生成可映射关系，让浏览器把执行位置还原到源码位置。
3. 浏览器能否“看到源码并正确断点”，取决于产物是否包含调试信息 + DevTools 是否启用对应能力 + 资源路径是否可访问。

#### 4.3.1 前置条件
1. 已安装并激活 Emscripten（命令行可识别 `em++`）。
2. 在仓库根目录执行命令：`D:\MyGitHub\wasm`。
3. 建议使用 PowerShell，且允许脚本执行策略。

#### 4.3.2 一次性生成全部模式
在仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_all.ps1 -DebugMode all
```

该命令会串行调用各 demo 的 `build.ps1`，分别产出：
- `release`（`-O2`）
- `dwarf`（`-O1 -g`）
- `sourcemap`（`-O1 -gsource-map`）

其中 `-O1` 的目的，是在保留一定可调试性的同时避免 `-O0` 带来的过大性能偏差。若你把优化开到更高，调试时可能出现“变量被优化掉/单步跳行”等现象。

#### 4.3.3 单独生成某一种模式
示例：只生成 DWARF。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_all.ps1 -DebugMode dwarf
```

示例：只生成 Source Map。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_all.ps1 -DebugMode sourcemap
```

若只构建单个 demo（例如 pthreads），可在仓库根目录执行：

```powershell
powershell -ExecutionPolicy Bypass -File demos/01-pthreads/build.ps1 -DebugMode dwarf
```

#### 4.3.4 产物目录与文件形态
所有 demo 都遵循同一布局：

- `demos/<demo>/output/release/*.js` 与 `*.wasm`
- `demos/<demo>/output/dwarf/*.js` 与 `*.wasm`
- `demos/<demo>/output/sourcemap/*.js` 与 `*.wasm`（通常伴随 map 关联信息）

核心差异不在入口文件名，而在编译参数与调试元数据。

#### 4.3.5 调试信息从编译到浏览器的传递链路
`dwarf` 传递链路：
1. `em++ -g` 在构建阶段保留 DWARF 调试信息。
2. 运行时加载 `*.wasm` 后，DevTools 基于 DWARF 元数据解析源码行号/符号。
3. 开发者可在 DevTools 中看到更接近 C++ 语义的断点与调用栈。

`sourcemap` 传递链路：
1. `em++ -gsource-map` 生成映射关系。
2. 浏览器加载入口 `*.js` 与 `*.wasm` 时，根据映射关系还原源码位置。
3. DevTools 在 Sources 面板展示映射后的源码视图，断点命中映射行。

这两条链路都要求“源码路径可被解析”。如果 map 或源码路径失配，常见现象是只能看到压缩后的胶水代码或匿名 Wasm 帧。

### 4.4 运行时切换与加载路径
所有 demo 页面按以下优先级选择模式：

1. URL 查询参数 `?debug=`（如 `?debug=dwarf`）。
2. `localStorage.wasmDebugMode`。
3. 默认 `release`。

随后动态加载 `output/<mode>/<artifact>.js`。例如：
- pthreads: `output/dwarf/main.js`
- asyncify: `output/sourcemap/asyncify.js`
- manual-workers: `output/release/task.js`
- coroutine: `output/dwarf/coroutine.js`

该机制让调试模式可通过链接直接共享，例如：
- `/isolated/demos/01-pthreads/web/index.html?debug=dwarf`
- `/plain/demos/02-asyncify/web/index.html?debug=sourcemap`

### 4.5 在浏览器中验证调试信息是否生效

建议先启动本地服务，再访问 demo：

```powershell
python server.py
```

然后从 `http://localhost:8000/isolated/index.html` 或 `http://localhost:8000/plain/index.html` 进入对应页面。

#### 4.5.1 DWARF 验证要点
1. 以 `?debug=dwarf` 打开 demo 页面。
2. 打开 DevTools，触发一次运行。
3. 在 Sources 中确认可关联到 C++ 源文件（而非仅胶水 JS）。
4. 观察调用栈是否包含更可读的 C++ 语义信息。
5. 在 C++ 对应行设置断点，再次触发运行，验证断点命中与单步行为。

#### 4.5.2 Source Map 验证要点
1. 以 `?debug=sourcemap` 打开 demo 页面。
2. 打开 DevTools 并触发运行。
3. 在 Sources 中确认映射后的源码可定位。
4. 设置断点后验证是否命中预期源码行。
5. 在 Network 面板确认 map 资源请求成功（状态码 200，路径正确）。

#### 4.5.3 常见失败现象与排查
1. 现象：只能看到 JS 胶水代码。排查：确认 URL 使用了 `?debug=dwarf` 或 `?debug=sourcemap`，且 `output/<mode>` 产物存在。
2. 现象：断点命中位置偏移。排查：确认当前运行产物与源码版本一致，重新全量构建后硬刷新。
3. 现象：Source Map 不生效。排查：检查 Network 中 map 请求是否 404，确认静态服务路径与 map 引用一致。
4. 现象：调用栈符号不完整。排查：避免过高优化级别，优先使用当前文档推荐的 `-O1` 调试配置。

### 4.6 DWARF 与 Source Map 的优劣对比

| 维度 | DWARF (`-g`) | Source Map (`-gsource-map`) |
|---|---|---|
| 调试信息形态 | 调试信息随 Wasm/相关符号信息存在 | 通过映射机制将执行位置映射回源码 |
| C++ 语义保真 | 通常更强，接近原生调试语义 | 取决于映射完整度与浏览器支持 |
| 断点体验 | 对复杂 C++ 场景更友好 | 对前端工程师较直观，入口一致 |
| 产物体积 | 通常更大 | 额外 map 文件与映射处理成本 |
| 浏览器依赖 | 对 DevTools 能力更敏感 | 对 Source Map 处理链路更敏感 |
| 团队协作 | 偏 C++/底层排障团队 | 偏前端/全栈协作团队 |

补充理解：
1. DWARF 更像“把原生调试信息带进 Wasm 运行时”。
2. Source Map 更像“把执行位置映射回你熟悉的源码视图”。
3. 二者不是互斥关系，团队可以同时产出，按问题类型切换。

### 4.7 典型选型建议
1. 以 C++ 逻辑排障为主（线程同步、状态机、复杂栈）：优先 `dwarf`。
2. 以跨角色协作为主（前端与 Wasm 联调）：优先 `sourcemap`。
3. 性能回归与功能验证阶段：默认 `release`，仅在问题复现时切换 `dwarf` 或 `sourcemap`。
4. 团队实践建议：CI 同时保留 `release + dwarf`，`sourcemap` 可按需或夜间任务生成。

### 4.8 设计价值
该机制将“调试策略”从构建脚本内隐参数提升为“页面可见、可切换、可分享链接”的显式能力，显著降低协作沟通成本，并能在同一套 demo 中快速完成“性能验证”和“源码级定位”的模式切换。

## 5. 统一对比面板的观测方法

### 5.1 事件协议
每个 demo 向父窗口发送统一事件：

- `ready`
- `run-start`
- `log`
- `run-end`
- `warning`

### 5.2 采集维度
`compare.html` 对每个方案维护：

- 当前状态（loading/ready/running）
- 最近耗时（last duration）
- 运行次数（runs）
- 统一日志流（event log）

### 5.3 可对比结论类型
面板支持快速回答以下问题：

1. 哪个方案在当前浏览器/模式下可运行。
2. 哪个方案对隔离头敏感。
3. 在相同 workload 下，四种策略的相对耗时。
4. 在不同调试模式下，运行行为是否一致。

## 6. 安全与部署考量

### 6.1 为什么要保留 plain 模式
plain 模式不是“生产推荐配置”，而是实验基线。它帮助团队识别：

- 某方案是否强依赖隔离策略。
- 页面在无隔离条件下的退化行为。
- 安全头配置缺失时的错误特征。

### 6.2 隔离模式的部署要求
若生产使用 pthreads，建议将隔离头配置纳入服务网关/反向代理标准模板，避免环境漂移导致功能失效。

## 7. 方案对比与选型建议

### 7.1 维度化对比
可从以下维度评估：

1. 并行能力（真并行 vs 协作并发）。
2. 部署复杂度（是否依赖隔离头）。
3. 代码迁移成本（原生 C++ 代码改动量）。
4. 调试体验（源码映射质量）。
5. 性能稳定性（任务粒度与通信开销）。

### 7.2 典型选型路径
- 已有 pthread 代码且追求并行性能：优先 pthreads。
- 以流程编排为主且不追求并行：可考虑 coroutine / asyncify。
- 任务天然分片、JS 控制强：manual workers 常更灵活。

## 8. 项目工程实践总结

### 8.1 成功实践
1. 通过 `output/<mode>` 统一产物命名，避免调试模式混淆。
2. 通过 `/isolated/` 与 `/plain/` 双路径在同服务中实现 A/B 验证。
3. 通过统一事件协议将“分散 demo”整合为“可观测系统”。

### 8.2 可改进方向
1. 增加自动化基准脚本，导出多轮统计结果（均值/方差）。
2. 增加 CI 任务验证三种 debug 模式都可构建。
3. 为 compare 面板增加 CSV 导出与趋势图。

## 9. 未来路线图建议

### 9.1 短期
- 加入统一 README 门户，汇总入口、调试、验证矩阵。
- 面板增加“隔离/普通模式切换提示条”。

### 9.2 中期
- 引入真实业务算子（图像处理、数值计算）替代演示 workload。
- 增加 Firefox/Chrome 差异观测报告模板。

### 9.3 长期
- 将该平台扩展为团队 Wasm 技术评估基座。
- 接入性能追踪与回归门禁，形成工程化决策闭环。

## 10. 结论
本项目并非单一技术 Demo，而是一个“Wasm 并发与调试实验框架”。其核心价值在于将技术讨论从抽象观点转化为可复现、可观测、可比较的工程事实。

通过四种并发方案、双服务安全模式、三类调试产物与统一对比面板，项目提供了一个可用于教学、评审、选型和演进的完整实践路径。
