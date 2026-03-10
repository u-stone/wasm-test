#include <emscripten.h>

#include "domain/simulation.h"
#include "platform/log_sink.h"

extern "C" {

void EMSCRIPTEN_KEEPALIVE run_cmake_demo() {
  platform::JsConsoleLogSink sink;
  domain::RunBusinessSimulation(sink);
}

}
