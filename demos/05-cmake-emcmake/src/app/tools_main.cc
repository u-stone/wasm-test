#include <emscripten.h>

#include "domain/report.h"
#include "platform/log_sink.h"

extern "C" {

void EMSCRIPTEN_KEEPALIVE run_cmake_tools_demo() {
  platform::JsConsoleLogSink sink;
  domain::RunToolsReport(sink);
}

}
