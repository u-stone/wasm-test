#pragma once

namespace platform {

class LogSink {
 public:
  virtual ~LogSink() = default;
  virtual void Info(const char* message) = 0;
};

class JsConsoleLogSink final : public LogSink {
 public:
  void Info(const char* message) override;
};

}  // namespace platform
