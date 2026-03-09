#include <cstdio>
#include <emscripten.h>

extern "C" {
EM_JS(void, jsPrint, (const char* str), {
  console.log(UTF8ToString(str));
});

void EMSCRIPTEN_KEEPALIVE run_asyncify_demo() {
  jsPrint("[LOG][scheme=asyncify][level=INFO] event=run_start");

  for (int task = 0; task < 4; ++task) {
    char message[128];
    std::snprintf(message, sizeof(message), "[LOG][scheme=asyncify][level=INFO] event=task_step task=%d step=1", task);
    jsPrint(message);

    // Yield to the browser event loop to simulate cooperative scheduling.
    emscripten_sleep(0);

    std::snprintf(message, sizeof(message), "[LOG][scheme=asyncify][level=INFO] event=task_step task=%d step=2", task);
    jsPrint(message);
  }

  jsPrint("[LOG][scheme=asyncify][level=INFO] event=run_complete");
}
}
