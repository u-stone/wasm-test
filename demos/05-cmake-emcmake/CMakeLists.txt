cmake_minimum_required(VERSION 3.20)
project(cmake_emcmake_demo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(WasmBuild)

initialize_wasm_build_defaults(
  SOURCE_MAP_ROOT "http://localhost:8000"
  ENV "demos"
  PROJECT_SEGMENT "05-cmake-emcmake"
  TARGET_SEGMENT "output"
)

create_wasm_debug_interface(cmake_project_debug_info)

print_wasm_build_summary()

add_subdirectory(src)

configure_wasm_build(
  cmake_demo
  EXPORTED_FUNCTIONS "[\"_run_cmake_demo\"]"
  EXPORTED_RUNTIME_METHODS "[\"ccall\"]"
)

configure_wasm_build(
  cmake_tools_demo
  EXPORTED_FUNCTIONS "[\"_run_cmake_tools_demo\"]"
  EXPORTED_RUNTIME_METHODS "[\"ccall\"]"
)
