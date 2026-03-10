cmake_minimum_required(VERSION 3.20)
project(cmake_emcmake_demo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(WasmSourceMap)

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

set(WASM_COMPILE_FLAGS)
set(WASM_LINK_FLAGS)

if(WASM_DEBUG_MODE STREQUAL "release")
  list(APPEND WASM_COMPILE_FLAGS -O2)
  list(APPEND WASM_LINK_FLAGS -O2)
elseif(WASM_DEBUG_MODE STREQUAL "dwarf")
  list(APPEND WASM_COMPILE_FLAGS -O0 -g)
  list(APPEND WASM_LINK_FLAGS -O0 -g)
elseif(WASM_DEBUG_MODE STREQUAL "sourcemap")
  list(APPEND WASM_COMPILE_FLAGS -O1)
  list(APPEND WASM_LINK_FLAGS -O1)
else()
  message(FATAL_ERROR "Unsupported WASM_DEBUG_MODE: ${WASM_DEBUG_MODE}")
endif()

message(STATUS "WASM_DEBUG_MODE=${WASM_DEBUG_MODE}")
if(WASM_DEBUG_MODE STREQUAL "sourcemap")
  message(STATUS "WASM_SOURCE_MAP_ROOT=${WASM_SOURCE_MAP_ROOT}")
  message(STATUS "WASM_ENV=${WASM_ENV}")
  message(STATUS "WASM_PROJECT=${WASM_PROJECT}")
  message(STATUS "WASM_BUILD_ID=${WASM_BUILD_ID}")
  message(STATUS "WASM_SOURCE_MAP_TARGET_SEGMENT=${WASM_SOURCE_MAP_TARGET_SEGMENT}")
endif()

add_compile_options(${WASM_COMPILE_FLAGS})

add_subdirectory(src)

set_target_properties(cmake_demo PROPERTIES
  SUFFIX ".js"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/output/${WASM_DEBUG_MODE}"
)

target_link_options(cmake_demo PRIVATE
  ${WASM_LINK_FLAGS}
  "-sEXPORTED_FUNCTIONS=[\"_run_cmake_demo\"]"
  "-sEXPORTED_RUNTIME_METHODS=[\"ccall\"]"
)

configure_wasm_sourcemap(cmake_demo "${WASM_SOURCE_MAP_TARGET_SEGMENT}")
