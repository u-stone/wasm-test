# WebAssembly 多线程与并发模型总结

## 1. 核心问题：为什么浏览器运行 C++ 多线程需要 SharedArrayBuffer？

在浏览器中运行 C++ 编译的 WebAssembly (Wasm) 时，我们面临着两种截然不同的“世界观”冲突：

*   **浏览器的默认世界（隔离）**：
    *   浏览器使用 **Web Workers** 来处理多任务。
    *   默认情况下，每个 Worker 就像是一个**完全独立的房间**。
    *   房间之间无法直接看到对方的东西，只能通过 `postMessage` **传递副本**（Copy）。
*   **C++ 的默认世界（共享）**：
    *   C++ 的多线程（`std::thread`）假设所有线程都在**同一个房间**里。
    *   它们共享同一个地址空间（内存），线程 A 修改了变量，线程 B 应该立刻就能看到。

**解决方案：SharedArrayBuffer**
为了让 C++ 在浏览器里“感觉像在家一样”，我们需要打破 Worker 间的墙壁：
*   **SharedArrayBuffer** 是 JavaScript 中唯一允许不同 Worker（房间）**共享同一块物理内存**的机制。
*   它配合 `Atomics` API（原子操作），让 Wasm 能够实现 C++ 所需的锁（Mutex）和同步机制。

**更深入的理解：为什么 SharedArrayBuffer 至关重要？**
没有 `SharedArrayBuffer`，每个 Web Worker 就像生活在真空里，无法与其它线程共享数据。C++ 编译到 Wasm 的多线程代码，本质上是多个 Web Worker 尝试访问同一块内存。`SharedArrayBuffer` 就像是打破了这层真空，使得多个 Worker 能够对同一块内存进行读写，实现真正意义上的多线程。 如果浏览器不支持 `SharedArrayBuffer`，则无法正常运行多线程的 Wasm 程序，或者只能退化到单线程的模拟状态，性能会大打折扣。

---

## 2. 并发模型大比拼：共享内存 vs. 消息传递

为了理解不同语言的设计哲学，我们可以使用以下生动的比喻：

### A. 共享内存模型 (Shared Memory)
*   **代表语言**：C++, Java, C# (以及开启了多线程的 Wasm)
*   **核心比喻：共用白板**
    *   想象所有员工（线程）都在**同一个办公室**工作。
    *   墙上有一块巨大的**白板（内存）**。
    *   任何员工都可以随时走过去，擦掉上面的字，写上新的内容。
*   **优点**：
    *   **极速**：A 写完 B 马上就能看，不需要走动传递，**零拷贝**（Zero Copy）。
*   **缺点**：
    *   **混乱（数据竞争）**：如果 A 正在写 "Hello"，刚写了一半，B 冲过来把它擦掉写成了 "World"，白板上就乱套了。
    *   **复杂**：为了防止混乱，必须引入“锁”（比如规定谁拿着唯一的板擦谁才能写），这容易导致死锁。

### B. 消息传递模型 (Message Passing)
*   **代表语言**：JavaScript (Web Workers), Go (CSP), Erlang
*   **核心比喻：传递纸条**
    *   想象每个员工（线程）都被关在**完全隔离的单间**里。
    *   他们根本看不到别人的房间。
    *   如果 A 想告诉 B 一件事，A 必须写一张**纸条（消息）**，从门缝塞给 B。
    *   B 收到后，手里拿的是纸条的**副本**。
*   **优点**：
    *   **安全**：因为房间隔离，永远不可能发生“两个人同时抢着写同一个字”的情况。逻辑清晰。
*   **缺点**：
    *   **开销**：写纸条、传纸条（复制数据）需要时间，传输大量数据时比较慢。

---

## 3. 特殊的第三者：Rust (所有权模型)
Rust 语言非常独特，它试图兼得二者之长。
*   它允许使用**共享内存**（为了高性能）。
*   但它有一个极其严格的“管理员”（编译器）。
*   **规则**：同一时间，要么只有一个人能修改数据，要么有多个人能读取数据，绝不允许同时发生。
*   **结果**：它在编译阶段就消灭了数据竞争，既有 C++ 的速度，又有消息传递模型的安全性。

## 4. 总结
WebAssembly 在浏览器中的多线程实现，本质上是利用 `SharedArrayBuffer` 在隔离的 Web Workers 之间搭建了一座共享内存的桥梁。这使得基于共享内存模型的语言（如 C++）能够将其并发逻辑移植到 Web 平台。理解这一机制，以及它与 JavaScript 原生消息传递模型的区别，对于开发高性能的 Web 应用至关重要。

## 5. 实战示例代码与编译

为了将理论付诸实践，以下提供了完整的示例代码及编译运行说明。

### 1. C++ 源码 (`main.cc`)
这是一个使用 `std::thread` 创建线程并执行计算任务的简单示例。

```cpp
#include <iostream>
#include <thread>
#include <vector>
#include <emscripten.h>

// EMSCRIPTEN_KEEPALIVE 使得这个函数可以从 JavaScript 调用
extern "C" {
    EM_JS(void, jsPrint, (const char* str), {
        console.log(UTF8ToString(str));
    });

    void EMSCRIPTEN_KEEPALIVE run_threads(int num_threads) {
        std::vector<std::thread> threads;

        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([i]() {
                // 模拟一些计算密集型任务
                for (int j = 0; j < 100000; ++j) {
                    double result = sin(i * j);
                }
                // 使用 EM_JS 宏来调用 JavaScript 函数
                char message[50];
                sprintf(message, "Thread %d 完成!", i);
                jsPrint(message);
            });
        }

        for (auto& thread : threads) {
            thread.join();
        }

        jsPrint("所有线程完成!");
    }
}
```

### 2. 前端页面 (`index.html`)
用于加载 Wasm 模块并触发多线程任务。

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Emscripten 多线程测试</title>
</head>
<body>
    <h1>Emscripten 多线程测试</h1>
    <script>
        // 检查浏览器是否支持 SharedArrayBuffer
        // if (typeof SharedArrayBuffer === 'undefined') {
        //     alert('您的浏览器不支持 SharedArrayBuffer，多线程可能无法正常工作。');
        // }

        // 加载 WASM 模块
        Module = {
            onRuntimeInitialized: function() {
                console.log('WASM 模块加载完成!');
                // 调用 C++ 函数，启动 4 个线程
                Module.ccall('run_threads', null, ['number'], [4]);
            }
        };
    </script>
    <script src="main.js"></script>
</body>
</html>
```

### 3. 编译命令
使用 Emscripten 编译时，关键在于启用 `USE_PTHREADS` 和设置线程池大小。

```bash
emcc main.cc -o main.js \
    -s USE_PTHREADS=1 \
    -s PTHREAD_POOL_SIZE=4 \
    -s EXPORTED_RUNTIME_METHODS=["ccall"] \
    -O3
```

*   `-s USE_PTHREADS=1`: 启用多线程支持（生成 SharedArrayBuffer 代码）。
*   `-s PTHREAD_POOL_SIZE=4`: 预创建 4 个 Web Workers，避免运行时创建的延迟和限制。
*   `-s EXPORTED_RUNTIME_METHODS=["ccall"]`: 导出 `ccall` 以便在 JS 中调用 C++ 函数。

### 4. 运行环境配置 (COOP/COEP)
由于安全限制，浏览器要求服务器必须发送以下响应头才能启用 `SharedArrayBuffer`：
*   `Cross-Origin-Opener-Policy: same-origin`
*   `Cross-Origin-Embedder-Policy: require-corp`