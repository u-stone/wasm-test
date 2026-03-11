include_guard(GLOBAL)

include(CMakeParseArguments)

function(initialize_wasm_sourcemap_defaults)
  set(options)
  set(oneValueArgs SOURCE_MAP_ROOT ENV PROJECT_SEGMENT BUILD_ID TARGET_SEGMENT)
  cmake_parse_arguments(WASM_SOURCEMAP "${options}" "${oneValueArgs}" "" ${ARGN})

  set(default_source_map_root "http://localhost:8000")
  if(NOT "${WASM_SOURCEMAP_SOURCE_MAP_ROOT}" STREQUAL "")
    set(default_source_map_root "${WASM_SOURCEMAP_SOURCE_MAP_ROOT}")
  elseif(DEFINED WASM_SOURCE_MAP_ROOT AND NOT "${WASM_SOURCE_MAP_ROOT}" STREQUAL "")
    set(default_source_map_root "${WASM_SOURCE_MAP_ROOT}")
  endif()

  set(default_env "demos")
  if(NOT "${WASM_SOURCEMAP_ENV}" STREQUAL "")
    set(default_env "${WASM_SOURCEMAP_ENV}")
  elseif(DEFINED WASM_ENV AND NOT "${WASM_ENV}" STREQUAL "")
    set(default_env "${WASM_ENV}")
  endif()

  set(default_project_segment "${PROJECT_NAME}")
  if(NOT "${WASM_SOURCEMAP_PROJECT_SEGMENT}" STREQUAL "")
    set(default_project_segment "${WASM_SOURCEMAP_PROJECT_SEGMENT}")
  elseif(DEFINED WASM_PROJECT AND NOT "${WASM_PROJECT}" STREQUAL "")
    set(default_project_segment "${WASM_PROJECT}")
  endif()

  set(default_build_id "${WASM_DEBUG_MODE}")
  if(NOT "${WASM_SOURCEMAP_BUILD_ID}" STREQUAL "")
    set(default_build_id "${WASM_SOURCEMAP_BUILD_ID}")
  elseif(DEFINED WASM_BUILD_ID AND NOT "${WASM_BUILD_ID}" STREQUAL "")
    set(default_build_id "${WASM_BUILD_ID}")
  endif()

  set(default_target_segment "output")
  if(NOT "${WASM_SOURCEMAP_TARGET_SEGMENT}" STREQUAL "")
    set(default_target_segment "${WASM_SOURCEMAP_TARGET_SEGMENT}")
  elseif(DEFINED WASM_SOURCE_MAP_TARGET_SEGMENT AND NOT "${WASM_SOURCE_MAP_TARGET_SEGMENT}" STREQUAL "")
    set(default_target_segment "${WASM_SOURCE_MAP_TARGET_SEGMENT}")
  endif()

  set(
    WASM_SOURCE_MAP_ROOT
    "${default_source_map_root}"
    CACHE STRING
    "Base URL used for --source-map-base when WASM_DEBUG_MODE=sourcemap"
  )
  set(
    WASM_ENV
    "${default_env}"
    CACHE STRING
    "Environment or top-level path segment for sourcemap assets"
  )
  set(
    WASM_PROJECT
    "${default_project_segment}"
    CACHE STRING
    "Logical project segment for sourcemap assets"
  )
  set(
    WASM_BUILD_ID
    "${default_build_id}"
    CACHE STRING
    "Build identifier used in sourcemap URLs"
  )
  set(
    WASM_SOURCE_MAP_TARGET_SEGMENT
    "${default_target_segment}"
    CACHE STRING
    "Target-specific path segment used in sourcemap URLs"
  )
endfunction()

function(_wasm_trim_slashes input output)
  set(value "${input}")
  string(REGEX REPLACE "^/+" "" value "${value}")
  string(REGEX REPLACE "/+$" "" value "${value}")
  set(${output} "${value}" PARENT_SCOPE)
endfunction()

function(_wasm_normalize_root input output)
  set(value "${input}")
  string(REGEX REPLACE "/+$" "" value "${value}")
  set(${output} "${value}" PARENT_SCOPE)
endfunction()

function(wasm_compute_source_map_base out_var target_segment)
  if(WASM_SOURCE_MAP_ROOT STREQUAL "")
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  _wasm_normalize_root("${WASM_SOURCE_MAP_ROOT}" base)
  foreach(segment IN ITEMS "${WASM_ENV}" "${WASM_PROJECT}" "${target_segment}" "${WASM_BUILD_ID}")
    _wasm_trim_slashes("${segment}" normalized)
    if(NOT normalized STREQUAL "")
      string(APPEND base "/${normalized}")
    endif()
  endforeach()

  string(APPEND base "/")
  set(${out_var} "${base}" PARENT_SCOPE)
endfunction()

function(configure_wasm_sourcemap target target_segment)
  if(NOT WASM_DEBUG_MODE STREQUAL "sourcemap")
    return()
  endif()

  wasm_compute_source_map_base(base "${target_segment}")
  if("${base}" STREQUAL "")
    message(STATUS "WASM source map base disabled for ${target}")
    return()
  endif()

  target_link_options(${target} PRIVATE
    "-gsource-map"
    "--source-map-base=${base}"
  )

  message(STATUS "WASM_SOURCE_MAP_BASE(${target})=${base}")
endfunction()
