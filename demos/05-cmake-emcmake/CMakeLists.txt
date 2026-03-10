cmake_minimum_required(VERSION 3.20)
project(cmake_emcmake_demo LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(WASM_DEBUG_MODE "release" CACHE STRING "Build mode folder name")
set_property(CACHE WASM_DEBUG_MODE PROPERTY STRINGS release dwarf sourcemap)
set(
  WASM_SOURCE_MAP_BASE
  "http://localhost:8000/demos/05-cmake-emcmake/output/sourcemap/"
  CACHE STRING
  "Base URL used for --source-map-base when WASM_DEBUG_MODE=sourcemap"
)

set(WASM_COMPILE_FLAGS)
set(WASM_LINK_FLAGS)
set(WASM_SOURCE_MAP_BASE_NORMALIZED "${WASM_SOURCE_MAP_BASE}")

if(NOT WASM_SOURCE_MAP_BASE_NORMALIZED STREQUAL "")
  if(NOT WASM_SOURCE_MAP_BASE_NORMALIZED MATCHES "/$")
    string(APPEND WASM_SOURCE_MAP_BASE_NORMALIZED "/")
  endif()
endif()

if(WASM_DEBUG_MODE STREQUAL "release")
  list(APPEND WASM_COMPILE_FLAGS -O2)
  list(APPEND WASM_LINK_FLAGS -O2)
elseif(WASM_DEBUG_MODE STREQUAL "dwarf")
  list(APPEND WASM_COMPILE_FLAGS -O0 -g)
  list(APPEND WASM_LINK_FLAGS -O0 -g)
elseif(WASM_DEBUG_MODE STREQUAL "sourcemap")
  list(APPEND WASM_COMPILE_FLAGS -O1)
  list(APPEND WASM_LINK_FLAGS -O1 -gsource-map)
  if(NOT WASM_SOURCE_MAP_BASE_NORMALIZED STREQUAL "")
    list(APPEND WASM_LINK_FLAGS "--source-map-base=${WASM_SOURCE_MAP_BASE_NORMALIZED}")
  endif()
else()
  message(FATAL_ERROR "Unsupported WASM_DEBUG_MODE: ${WASM_DEBUG_MODE}")
endif()

message(STATUS "WASM_DEBUG_MODE=${WASM_DEBUG_MODE}")
if(WASM_DEBUG_MODE STREQUAL "sourcemap")
  message(STATUS "WASM_SOURCE_MAP_BASE=${WASM_SOURCE_MAP_BASE_NORMALIZED}")
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
