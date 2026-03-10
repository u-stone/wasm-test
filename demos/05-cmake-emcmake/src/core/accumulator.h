#pragma once

namespace core {

class Accumulator {
 public:
  void Add(double value);
  double Total() const;

 private:
  double total_ = 0.0;
};

}  // namespace core
