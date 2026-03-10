#include <cstdio>
#include <emscripten.h>

extern "C" {
EM_JS(void, jsPrint, (const char* str), {
  console.log(UTF8ToString(str));
});

void EMSCRIPTEN_KEEPALIVE run_cmake_demo() {
  jsPrint("[LOG][scheme=cmake-emcmake][level=INFO] event=run_start");

  double sum = 0.0;
  for (int i = 1; i <= 5; ++i) {
    sum += i * 1.25;
    char message[160];
    std::snprintf(
        message,
        sizeof(message),
        "[LOG][scheme=cmake-emcmake][level=INFO] event=step step=%d partial=%.2f",
        i,
        sum);
    jsPrint(message);
  }

  char finalMsg[160];
  std::snprintf(
      finalMsg,
      sizeof(finalMsg),
      "[LOG][scheme=cmake-emcmake][level=INFO] event=run_complete result=%.2f",
      sum);
  jsPrint(finalMsg);
}
}
