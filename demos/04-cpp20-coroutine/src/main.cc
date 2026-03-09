#include <coroutine>
#include <cstdio>
#include <vector>
#include <emscripten.h>

extern "C" {
EM_JS(void, jsPrint, (const char* str), {
  console.log(UTF8ToString(str));
});
}

struct StepTask {
  struct promise_type {
    int current = 0;

    StepTask get_return_object() {
      return StepTask{std::coroutine_handle<promise_type>::from_promise(*this)};
    }
    std::suspend_always initial_suspend() noexcept { return {}; }
    std::suspend_always final_suspend() noexcept { return {}; }
    std::suspend_always yield_value(int value) noexcept {
      current = value;
      return {};
    }
    void return_void() {}
    void unhandled_exception() { std::terminate(); }
  };

  std::coroutine_handle<promise_type> handle;

  explicit StepTask(std::coroutine_handle<promise_type> h) : handle(h) {}
  StepTask(const StepTask&) = delete;
  StepTask& operator=(const StepTask&) = delete;
  StepTask(StepTask&& other) noexcept : handle(other.handle) { other.handle = {}; }
  StepTask& operator=(StepTask&& other) noexcept {
    if (this != &other) {
      if (handle) {
        handle.destroy();
      }
      handle = other.handle;
      other.handle = {};
    }
    return *this;
  }
  ~StepTask() {
    if (handle) {
      handle.destroy();
    }
  }

  bool resume() {
    if (!handle || handle.done()) {
      return false;
    }
    handle.resume();
    return !handle.done();
  }

  int value() const { return handle.promise().current; }
};

StepTask make_task(int id, int steps) {
  for (int i = 1; i <= steps; ++i) {
    co_yield i * 100 + id;
  }
}

extern "C" {
void EMSCRIPTEN_KEEPALIVE run_coroutine_demo() {
  std::vector<StepTask> tasks;
  tasks.emplace_back(make_task(1, 4));
  tasks.emplace_back(make_task(2, 4));
  tasks.emplace_back(make_task(3, 4));

  bool hasActive = true;
  while (hasActive) {
    hasActive = false;
    for (size_t i = 0; i < tasks.size(); ++i) {
      const bool stillRunning = tasks[i].resume();
      if (stillRunning) {
        hasActive = true;
        char message[160];
        std::snprintf(
            message,
            sizeof(message),
            "[LOG][scheme=coroutine][level=INFO] event=task_yield task=%d value=%d",
            static_cast<int>(i + 1),
            tasks[i].value());
        jsPrint(message);
      }
    }
  }

  jsPrint("[LOG][scheme=coroutine][level=INFO] event=run_complete model=single_thread_cooperative");
}
}
