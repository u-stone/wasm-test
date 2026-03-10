#include "domain/report.h"

#include <cstdio>

#include "core/accumulator.h"
#include "platform/log_sink.h"

namespace domain {

void RunToolsReport(platform::LogSink& sink) {
  sink.Info("[LOG][scheme=cmake-emcmake][target=tools][level=INFO] event=run_start");

  core::Accumulator accumulator;
  constexpr double samples[] = {2.5, 4.0, 6.5, 3.0};
  for (int index = 0; index < 4; ++index) {
    accumulator.Add(samples[index]);

    char message[192];
    std::snprintf(
        message,
        sizeof(message),
        "[LOG][scheme=cmake-emcmake][target=tools][level=INFO] event=report_step item=%d subtotal=%.2f",
        index + 1,
        accumulator.Total());
    sink.Info(message);
  }

  char finalMessage[192];
  std::snprintf(
      finalMessage,
      sizeof(finalMessage),
      "[LOG][scheme=cmake-emcmake][target=tools][level=INFO] event=run_complete result=%.2f",
      accumulator.Total());
  sink.Info(finalMessage);
}

}  // namespace domain
