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

/*
int main() {
    run_threads(4);
    return 0;
}
*/