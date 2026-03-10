#include "platform/log_sink.h"

#include <emscripten.h>

namespace {
EM_JS(void, jsPrint, (const char* str), {
  console.log(UTF8ToString(str));
});
}  // namespace

namespace platform {

void JsConsoleLogSink::Info(const char* message) {
  jsPrint(message);
}

}  // namespace platform
