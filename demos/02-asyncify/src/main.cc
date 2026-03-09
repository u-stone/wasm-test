#include <cstdio>
#include <emscripten.h>

extern "C" {
EM_JS(void, jsPrint, (const char* str), {
  console.log(UTF8ToString(str));
});

void EMSCRIPTEN_KEEPALIVE run_asyncify_demo() {
  jsPrint("[asyncify] start");

  for (int task = 0; task < 4; ++task) {
    char message[80];
    std::snprintf(message, sizeof(message), "[asyncify] task %d step 1", task);
    jsPrint(message);

    // Yield to the browser event loop to simulate cooperative scheduling.
    emscripten_sleep(0);

    std::snprintf(message, sizeof(message), "[asyncify] task %d step 2", task);
    jsPrint(message);
  }

  jsPrint("[asyncify] end");
}
}
