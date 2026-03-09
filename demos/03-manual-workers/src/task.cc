#include <cmath>
#include <emscripten.h>

extern "C" {

double EMSCRIPTEN_KEEPALIVE run_heavy_task(int worker_id, int iterations) {
  double acc = 0.0;
  for (int i = 1; i <= iterations; ++i) {
    acc += std::sin((worker_id + 1) * i * 0.001);
  }
  return acc;
}

}
