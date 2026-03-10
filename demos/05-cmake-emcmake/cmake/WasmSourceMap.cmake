include_guard(GLOBAL)

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
  if(base STREQUAL "")
    message(STATUS "WASM source map base disabled for ${target}")
    return()
  endif()

  target_link_options(${target} PRIVATE
    "-gsource-map"
    "--source-map-base=${base}"
  )

  message(STATUS "WASM_SOURCE_MAP_BASE(${target})=${base}")
endfunction()
