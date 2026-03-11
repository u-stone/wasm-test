include_guard(GLOBAL)

include(CMakeParseArguments)
include(WasmSourceMap)

function(initialize_wasm_build_defaults)
  set(options)
  set(oneValueArgs DEBUG_MODE SOURCE_MAP_ROOT ENV PROJECT_SEGMENT BUILD_ID TARGET_SEGMENT)
  cmake_parse_arguments(WASM_BUILD_INIT "${options}" "${oneValueArgs}" "" ${ARGN})

  set(default_debug_mode "release")
  if(NOT "${WASM_BUILD_INIT_DEBUG_MODE}" STREQUAL "")
    set(default_debug_mode "${WASM_BUILD_INIT_DEBUG_MODE}")
  elseif(DEFINED WASM_DEBUG_MODE AND NOT "${WASM_DEBUG_MODE}" STREQUAL "")
    set(default_debug_mode "${WASM_DEBUG_MODE}")
  endif()

  set(WASM_DEBUG_MODE "${default_debug_mode}" CACHE STRING "Build mode folder name")
  set_property(CACHE WASM_DEBUG_MODE PROPERTY STRINGS release dwarf sourcemap)

  initialize_wasm_sourcemap_defaults(
    SOURCE_MAP_ROOT "${WASM_BUILD_INIT_SOURCE_MAP_ROOT}"
    ENV "${WASM_BUILD_INIT_ENV}"
    PROJECT_SEGMENT "${WASM_BUILD_INIT_PROJECT_SEGMENT}"
    BUILD_ID "${WASM_BUILD_INIT_BUILD_ID}"
    TARGET_SEGMENT "${WASM_BUILD_INIT_TARGET_SEGMENT}"
  )
endfunction()

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
  set(oneValueArgs SOURCE_MAP_TARGET_SEGMENT EXPORTED_FUNCTIONS EXPORTED_RUNTIME_METHODS OUTPUT_DIRECTORY TARGET_SUFFIX)
  cmake_parse_arguments(WASM_BUILD "${options}" "${oneValueArgs}" "" ${ARGN})

  if(NOT TARGET ${target})
    message(FATAL_ERROR "configure_wasm_build: target '${target}' does not exist")
  endif()

  set(target_suffix ".js")
  if(NOT "${WASM_BUILD_TARGET_SUFFIX}" STREQUAL "")
    set(target_suffix "${WASM_BUILD_TARGET_SUFFIX}")
  endif()

  set(output_directory "${CMAKE_SOURCE_DIR}/output/${WASM_DEBUG_MODE}")
  if(NOT "${WASM_BUILD_OUTPUT_DIRECTORY}" STREQUAL "")
    set(output_directory "${WASM_BUILD_OUTPUT_DIRECTORY}")
  endif()

  set(source_map_target_segment "${WASM_SOURCE_MAP_TARGET_SEGMENT}")
  if(NOT "${WASM_BUILD_SOURCE_MAP_TARGET_SEGMENT}" STREQUAL "")
    set(source_map_target_segment "${WASM_BUILD_SOURCE_MAP_TARGET_SEGMENT}")
  endif()

  set_target_properties(${target} PROPERTIES SUFFIX "${target_suffix}")
  if(NOT "${output_directory}" STREQUAL "")
    set_target_properties(${target} PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY "${output_directory}"
    )
  endif()

  apply_wasm_compile_options(${target})
  get_wasm_link_flags(link_flags)

  if(NOT "${WASM_BUILD_EXPORTED_FUNCTIONS}" STREQUAL "")
    list(APPEND link_flags "-sEXPORTED_FUNCTIONS=${WASM_BUILD_EXPORTED_FUNCTIONS}")
  endif()

  if(NOT "${WASM_BUILD_EXPORTED_RUNTIME_METHODS}" STREQUAL "")
    list(APPEND link_flags "-sEXPORTED_RUNTIME_METHODS=${WASM_BUILD_EXPORTED_RUNTIME_METHODS}")
  endif()

  target_link_options(${target} PRIVATE ${link_flags})

  if(NOT "${source_map_target_segment}" STREQUAL "")
    configure_wasm_sourcemap(${target} "${source_map_target_segment}")
  endif()

  message(STATUS "WASM_OUTPUT_DIRECTORY(${target})=${output_directory}")
  set(js_output_path "${output_directory}/${target}${target_suffix}")
  set(wasm_output_path "${output_directory}/${target}.wasm")
  message(STATUS "WASM_JS_OUTPUT(${target})=${js_output_path}")
  message(STATUS "WASM_BINARY_OUTPUT(${target})=${wasm_output_path}")

  if(WASM_DEBUG_MODE STREQUAL "sourcemap")
    message(STATUS "WASM_SOURCE_MAP_TARGET_SEGMENT_EFFECTIVE(${target})=${source_map_target_segment}")
    set(map_output_path "${output_directory}/${target}.wasm.map")
    message(STATUS "WASM_SOURCE_MAP_FILE(${target})=${map_output_path}")

    wasm_compute_source_map_base(base "${source_map_target_segment}")
    if(NOT "${base}" STREQUAL "")
      message(STATUS "WASM_SOURCE_MAP_URL_BASE(${target})=${base}")
    endif()
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
