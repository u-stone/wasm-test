#include "core/accumulator.h"

namespace core {

void Accumulator::Add(double value) {
  total_ += value;
}

double Accumulator::Total() const {
  return total_;
}

}  // namespace core
