cmake_minimum_required(VERSION 3.20)
project(cmake_emcmake_demo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(WASM_DEBUG_MODE "release" CACHE STRING "Build mode folder name")
set(WASM_DEBUG_FLAGS "-O2" CACHE STRING "Flags passed to emcc/em++")

separate_arguments(WASM_DEBUG_FLAGS_LIST NATIVE_COMMAND "${WASM_DEBUG_FLAGS}")

add_subdirectory(src)

set_target_properties(cmake_demo PROPERTIES
  SUFFIX ".js"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/output/${WASM_DEBUG_MODE}"
)

target_compile_options(cmake_demo PRIVATE ${WASM_DEBUG_FLAGS_LIST})
target_link_options(cmake_demo PRIVATE
  ${WASM_DEBUG_FLAGS_LIST}
  "-sEXPORTED_FUNCTIONS=[\"_run_cmake_demo\"]"
  "-sEXPORTED_RUNTIME_METHODS=[\"ccall\"]"
)
