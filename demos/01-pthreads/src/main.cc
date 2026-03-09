#include <cmath>
#include <cstdio>
#include <thread>
#include <vector>
#include <emscripten.h>

extern "C" {
    EM_JS(void, jsPrint, (const char* str), {
        console.log(UTF8ToString(str));
    });

    void EMSCRIPTEN_KEEPALIVE run_threads(int num_threads) {
        std::vector<std::thread> threads;

        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([i]() {
                // Simulate a CPU-heavy workload per thread.
                for (int j = 0; j < 100000; ++j) {
                    volatile double result = std::sin(i * j);
                    (void)result;
                }
                char message[50];
                std::snprintf(message, sizeof(message), "[pthreads] Thread %d finished", i);
                jsPrint(message);
            });
        }

        for (auto& thread : threads) {
            thread.join();
        }

        jsPrint("[pthreads] All threads finished");
    }
}