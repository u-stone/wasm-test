#include <cmath>
#include <cstdio>
#include <thread>
#include <vector>
#include <emscripten.h>
#include <emscripten/threading.h>

extern "C" {
    EM_JS(void, jsPrint, (const char* str), {
        console.log(UTF8ToString(str));
    });

    void logOnMainThread(const char* str) {
#ifdef __EMSCRIPTEN_PTHREADS__
        if (emscripten_is_main_runtime_thread()) {
            jsPrint(str);
            return;
        }
        // Forward worker log output to the main runtime thread so UI hooks can capture it.
        MAIN_THREAD_EM_ASM({
            console.log(UTF8ToString($0));
        }, str);
#else
        jsPrint(str);
#endif
    }

    void EMSCRIPTEN_KEEPALIVE run_threads(int num_threads) {
        std::vector<std::thread> threads;

        for (int i = 0; i < num_threads; ++i) {
            threads.emplace_back([i]() {
                // Simulate a CPU-heavy workload per thread.
                for (int j = 0; j < 100000; ++j) {
                    volatile double result = std::sin(i * j);
                    (void)result;
                }
                char message[128];
                std::snprintf(message, sizeof(message), "[LOG][scheme=pthreads][level=INFO] event=thread_done thread=%d", i);
                logOnMainThread(message);
            });
        }

        for (auto& thread : threads) {
            thread.join();
        }

        logOnMainThread("[LOG][scheme=pthreads][level=INFO] event=run_complete");
    }
}