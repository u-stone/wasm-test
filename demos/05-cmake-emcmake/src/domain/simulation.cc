#include "domain/simulation.h"

#include <cstdio>

#include "core/accumulator.h"
#include "platform/log_sink.h"

namespace domain {

void RunBusinessSimulation(platform::LogSink& sink) {
  sink.Info("[LOG][scheme=cmake-emcmake][level=INFO] event=run_start");

  core::Accumulator accumulator;
  for (int i = 1; i <= 5; ++i) {
    accumulator.Add(i * 1.25);

    char message[180];
    std::snprintf(
        message,
        sizeof(message),
        "[LOG][scheme=cmake-emcmake][level=INFO] event=step step=%d partial=%.2f",
        i,
        accumulator.Total());
    sink.Info(message);
  }

  char finalMessage[180];
  std::snprintf(
      finalMessage,
      sizeof(finalMessage),
      "[LOG][scheme=cmake-emcmake][level=INFO] event=run_complete result=%.2f",
      accumulator.Total());
  sink.Info(finalMessage);
}

}  // namespace domain
