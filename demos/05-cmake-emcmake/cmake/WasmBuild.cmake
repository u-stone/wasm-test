include(WasmSourceMap)

function(get_wasm_compile_flags out_var)
  set(compile_flags)

  if(WASM_DEBUG_MODE STREQUAL "release")
    list(APPEND compile_flags -O2)
  elseif(WASM_DEBUG_MODE STREQUAL "dwarf")
    list(APPEND compile_flags -O0 -g)
  elseif(WASM_DEBUG_MODE STREQUAL "sourcemap")
    # Source maps are emitted at link time, but object files still need debug info.
    list(APPEND compile_flags -O1 -g)
  else()
    message(FATAL_ERROR "Unsupported WASM_DEBUG_MODE: ${WASM_DEBUG_MODE}")
  endif()

  set(${out_var} "${compile_flags}" PARENT_SCOPE)
endfunction()

function(get_wasm_link_flags out_var)
  set(link_flags)

  if(WASM_DEBUG_MODE STREQUAL "release")
    list(APPEND link_flags -O2)
  elseif(WASM_DEBUG_MODE STREQUAL "dwarf")
    list(APPEND link_flags -O0 -g)
  elseif(WASM_DEBUG_MODE STREQUAL "sourcemap")
    list(APPEND link_flags -O1)
  else()
    message(FATAL_ERROR "Unsupported WASM_DEBUG_MODE: ${WASM_DEBUG_MODE}")
  endif()

  set(${out_var} "${link_flags}" PARENT_SCOPE)
endfunction()

function(apply_wasm_compile_options target)
  if(NOT TARGET ${target})
    message(FATAL_ERROR "apply_wasm_compile_options: target '${target}' does not exist")
  endif()

  get_wasm_compile_flags(compile_flags)
  target_compile_options(${target} PRIVATE ${compile_flags})
endfunction()

function(configure_wasm_build target)
  set(options)
  set(oneValueArgs SOURCE_MAP_TARGET_SEGMENT EXPORTED_FUNCTIONS EXPORTED_RUNTIME_METHODS)
  cmake_parse_arguments(WASM_BUILD "${options}" "${oneValueArgs}" "" ${ARGN})

  if(NOT TARGET ${target})
    message(FATAL_ERROR "configure_wasm_build: target '${target}' does not exist")
  endif()

  apply_wasm_compile_options(${target})
  get_wasm_link_flags(link_flags)

  if(NOT WASM_BUILD_EXPORTED_FUNCTIONS STREQUAL "")
    list(APPEND link_flags "-sEXPORTED_FUNCTIONS=${WASM_BUILD_EXPORTED_FUNCTIONS}")
  endif()

  if(NOT WASM_BUILD_EXPORTED_RUNTIME_METHODS STREQUAL "")
    list(APPEND link_flags "-sEXPORTED_RUNTIME_METHODS=${WASM_BUILD_EXPORTED_RUNTIME_METHODS}")
  endif()

  target_link_options(${target} PRIVATE ${link_flags})

  if(NOT WASM_BUILD_SOURCE_MAP_TARGET_SEGMENT STREQUAL "")
    configure_wasm_sourcemap(${target} "${WASM_BUILD_SOURCE_MAP_TARGET_SEGMENT}")
  endif()
endfunction()

function(print_wasm_build_summary)
  message(STATUS "WASM_DEBUG_MODE=${WASM_DEBUG_MODE}")
  get_wasm_compile_flags(compile_flags)
  get_wasm_link_flags(link_flags)
  string(JOIN " " compile_flags_str ${compile_flags})
  string(JOIN " " link_flags_str ${link_flags})
  message(STATUS "WASM_COMPILE_FLAGS=${compile_flags_str}")
  message(STATUS "WASM_LINK_FLAGS=${link_flags_str}")
  if(WASM_DEBUG_MODE STREQUAL "sourcemap")
    message(STATUS "WASM_SOURCE_MAP_ROOT=${WASM_SOURCE_MAP_ROOT}")
    message(STATUS "WASM_ENV=${WASM_ENV}")
    message(STATUS "WASM_PROJECT=${WASM_PROJECT}")
    message(STATUS "WASM_BUILD_ID=${WASM_BUILD_ID}")
    message(STATUS "WASM_SOURCE_MAP_TARGET_SEGMENT=${WASM_SOURCE_MAP_TARGET_SEGMENT}")
  endif()
endfunction()
