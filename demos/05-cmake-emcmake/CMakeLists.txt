cmake_minimum_required(VERSION 3.20)
project(cmake_emcmake_demo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(WasmBuild)

set(WASM_DEBUG_MODE "release" CACHE STRING "Build mode folder name")
set_property(CACHE WASM_DEBUG_MODE PROPERTY STRINGS release dwarf sourcemap)
set(
  WASM_SOURCE_MAP_ROOT
  "http://localhost:8000"
  CACHE STRING
  "Root URL for published sourcemap assets"
)
set(WASM_ENV "demos" CACHE STRING "Environment or top-level path segment for sourcemap assets")
set(WASM_PROJECT "05-cmake-emcmake" CACHE STRING "Logical project segment for sourcemap assets")
set(WASM_BUILD_ID "${WASM_DEBUG_MODE}" CACHE STRING "Build identifier used in sourcemap URLs")
set(
  WASM_SOURCE_MAP_TARGET_SEGMENT
  "output"
  CACHE STRING
  "Target-specific path segment used in sourcemap URLs"
)

print_wasm_build_summary()

add_subdirectory(src)

set_target_properties(cmake_demo PROPERTIES
  SUFFIX ".js"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/output/${WASM_DEBUG_MODE}"
)

configure_wasm_build(
  cmake_demo
  SOURCE_MAP_TARGET_SEGMENT "${WASM_SOURCE_MAP_TARGET_SEGMENT}"
  EXPORTED_FUNCTIONS "[\"_run_cmake_demo\"]"
  EXPORTED_RUNTIME_METHODS "[\"ccall\"]"
)
