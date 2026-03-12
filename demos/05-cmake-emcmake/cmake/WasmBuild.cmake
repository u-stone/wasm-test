include_guard(GLOBAL)

include(CMakeParseArguments)
include(WasmSourceMap)

function(initialize_wasm_build_defaults)
  set(options)
  set(oneValueArgs DEBUG_MODE DEBUG_INFO DEBUG_LEVEL SOURCE_MAP SOURCE_MAP_ROOT ENV PROJECT_SEGMENT BUILD_ID TARGET_SEGMENT)
  cmake_parse_arguments(WASM_BUILD_INIT "${options}" "${oneValueArgs}" "" ${ARGN})

  set(default_debug_mode "release")
  if(NOT "${WASM_BUILD_INIT_DEBUG_MODE}" STREQUAL "")
    set(default_debug_mode "${WASM_BUILD_INIT_DEBUG_MODE}")
  elseif(DEFINED WASM_DEBUG_MODE AND NOT "${WASM_DEBUG_MODE}" STREQUAL "")
    set(default_debug_mode "${WASM_DEBUG_MODE}")
  endif()

  set(WASM_DEBUG_MODE "${default_debug_mode}" CACHE STRING "Build mode folder name")
  set_property(CACHE WASM_DEBUG_MODE PROPERTY STRINGS release dwarf sourcemap)

  set(default_debug_info "auto")
  if(NOT "${WASM_BUILD_INIT_DEBUG_INFO}" STREQUAL "")
    set(default_debug_info "${WASM_BUILD_INIT_DEBUG_INFO}")
  elseif(DEFINED WASM_DEBUG_INFO AND NOT "${WASM_DEBUG_INFO}" STREQUAL "")
    set(default_debug_info "${WASM_DEBUG_INFO}")
  endif()

  set(default_debug_level "default")
  if(NOT "${WASM_BUILD_INIT_DEBUG_LEVEL}" STREQUAL "")
    set(default_debug_level "${WASM_BUILD_INIT_DEBUG_LEVEL}")
  elseif(DEFINED WASM_DEBUG_INFO_LEVEL AND NOT "${WASM_DEBUG_INFO_LEVEL}" STREQUAL "")
    set(default_debug_level "${WASM_DEBUG_INFO_LEVEL}")
  endif()

  set(WASM_DEBUG_INFO "${default_debug_info}" CACHE STRING "Whether to generate compile debug info: auto, on, off")
  set_property(CACHE WASM_DEBUG_INFO PROPERTY STRINGS auto on off)
  set(WASM_DEBUG_INFO_LEVEL "${default_debug_level}" CACHE STRING "Debug info level: default, 0, 1, 2, 3, line-tables-only")
  set_property(CACHE WASM_DEBUG_INFO_LEVEL PROPERTY STRINGS default 0 1 2 3 line-tables-only)

  set(default_source_map "auto")
  if(NOT "${WASM_BUILD_INIT_SOURCE_MAP}" STREQUAL "")
    set(default_source_map "${WASM_BUILD_INIT_SOURCE_MAP}")
  elseif(DEFINED WASM_SOURCE_MAP AND NOT "${WASM_SOURCE_MAP}" STREQUAL "")
    set(default_source_map "${WASM_SOURCE_MAP}")
  endif()

  set(WASM_SOURCE_MAP "${default_source_map}" CACHE STRING "Whether to generate sourcemaps for final wasm targets: auto, on, off")
  set_property(CACHE WASM_SOURCE_MAP PROPERTY STRINGS auto on off)

  initialize_wasm_sourcemap_defaults(
    SOURCE_MAP_ROOT "${WASM_BUILD_INIT_SOURCE_MAP_ROOT}"
    ENV "${WASM_BUILD_INIT_ENV}"
    PROJECT_SEGMENT "${WASM_BUILD_INIT_PROJECT_SEGMENT}"
    BUILD_ID "${WASM_BUILD_INIT_BUILD_ID}"
    TARGET_SEGMENT "${WASM_BUILD_INIT_TARGET_SEGMENT}"
  )
endfunction()

function(resolve_wasm_debug_info_enabled out_var)
  set(options)
  set(oneValueArgs DEBUG_INFO)
  cmake_parse_arguments(WASM_DEBUG_STATE "${options}" "${oneValueArgs}" "" ${ARGN})

  set(debug_info_mode "${WASM_DEBUG_INFO}")
  if(NOT "${WASM_DEBUG_STATE_DEBUG_INFO}" STREQUAL "")
    set(debug_info_mode "${WASM_DEBUG_STATE_DEBUG_INFO}")
  endif()

  string(TOLOWER "${debug_info_mode}" debug_info_mode)
  if(debug_info_mode STREQUAL "auto")
    if(WASM_DEBUG_MODE STREQUAL "release")
      set(debug_info_enabled FALSE)
    else()
      set(debug_info_enabled TRUE)
    endif()
  elseif(debug_info_mode STREQUAL "on")
    set(debug_info_enabled TRUE)
  elseif(debug_info_mode STREQUAL "off")
    set(debug_info_enabled FALSE)
  else()
    message(FATAL_ERROR "Unsupported debug info mode: ${debug_info_mode}. Expected auto, on, or off.")
  endif()

  set(${out_var} ${debug_info_enabled} PARENT_SCOPE)
endfunction()

function(resolve_wasm_source_map_enabled out_var)
  set(options)
  set(oneValueArgs SOURCE_MAP)
  cmake_parse_arguments(WASM_SOURCE_MAP_STATE "${options}" "${oneValueArgs}" "" ${ARGN})

  set(source_map_mode "${WASM_SOURCE_MAP}")
  if(NOT "${WASM_SOURCE_MAP_STATE_SOURCE_MAP}" STREQUAL "")
    set(source_map_mode "${WASM_SOURCE_MAP_STATE_SOURCE_MAP}")
  endif()

  string(TOLOWER "${source_map_mode}" source_map_mode)
  if(source_map_mode STREQUAL "auto")
    if(WASM_DEBUG_MODE STREQUAL "sourcemap")
      set(source_map_enabled TRUE)
    else()
      set(source_map_enabled FALSE)
    endif()
  elseif(source_map_mode STREQUAL "on")
    if(WASM_DEBUG_MODE STREQUAL "sourcemap")
      set(source_map_enabled TRUE)
    else()
      message(WARNING "WASM_SOURCE_MAP is 'on' but WASM_DEBUG_MODE='${WASM_DEBUG_MODE}'. Sourcemaps are only generated in 'sourcemap' mode, so source map output remains disabled.")
      set(source_map_enabled FALSE)
    endif()
  elseif(source_map_mode STREQUAL "off")
    set(source_map_enabled FALSE)
  else()
    message(FATAL_ERROR "Unsupported source map mode: ${source_map_mode}. Expected auto, on, or off.")
  endif()

  set(${out_var} ${source_map_enabled} PARENT_SCOPE)
endfunction()

function(resolve_wasm_debug_preset out_debug_info_var out_debug_level_var)
  set(options)
  set(oneValueArgs PRESET)
  cmake_parse_arguments(WASM_PRESET "${options}" "${oneValueArgs}" "" ${ARGN})

  set(preset "custom")
  if(NOT "${WASM_PRESET_PRESET}" STREQUAL "")
    set(preset "${WASM_PRESET_PRESET}")
  endif()

  string(TOLOWER "${preset}" preset)
  if(preset STREQUAL "custom")
    set(debug_info "")
    set(debug_level "")
  elseif(preset STREQUAL "minimal")
    set(debug_info on)
    set(debug_level line-tables-only)
  elseif(preset STREQUAL "full")
    set(debug_info on)
    set(debug_level 3)
  elseif(preset STREQUAL "balanced")
    set(debug_info on)
    set(debug_level 2)
  elseif(preset STREQUAL "disabled")
    set(debug_info off)
    set(debug_level default)
  else()
    message(FATAL_ERROR "Unsupported debug preset: ${preset}. Expected custom, minimal, balanced, full, or disabled.")
  endif()

  set(${out_debug_info_var} "${debug_info}" PARENT_SCOPE)
  set(${out_debug_level_var} "${debug_level}" PARENT_SCOPE)
endfunction()

function(get_wasm_debug_flag out_var)
  set(options)
  set(oneValueArgs DEBUG_LEVEL)
  cmake_parse_arguments(WASM_DEBUG_FLAG "${options}" "${oneValueArgs}" "" ${ARGN})

  set(debug_level "${WASM_DEBUG_INFO_LEVEL}")
  if(NOT "${WASM_DEBUG_FLAG_DEBUG_LEVEL}" STREQUAL "")
    set(debug_level "${WASM_DEBUG_FLAG_DEBUG_LEVEL}")
  endif()

  string(TOLOWER "${debug_level}" debug_level)
  if(debug_level STREQUAL "default")
    set(debug_flag -g)
  elseif(debug_level MATCHES "^[0-3]$")
    set(debug_flag "-g${debug_level}")
  elseif(debug_level STREQUAL "line-tables-only")
    set(debug_flag -gline-tables-only)
  else()
    message(FATAL_ERROR "Unsupported debug info level: ${debug_level}. Expected default, 0, 1, 2, 3, or line-tables-only.")
  endif()

  set(${out_var} "${debug_flag}" PARENT_SCOPE)
endfunction()

function(get_wasm_compile_flags out_var)
  set(options)
  set(oneValueArgs DEBUG_INFO DEBUG_LEVEL)
  set(multiValueArgs EXTRA_FLAGS)
  cmake_parse_arguments(WASM_COMPILE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  set(compile_flags)

  if(WASM_DEBUG_MODE STREQUAL "release")
    list(APPEND compile_flags -O2)
  elseif(WASM_DEBUG_MODE STREQUAL "dwarf")
    list(APPEND compile_flags -O0)
  elseif(WASM_DEBUG_MODE STREQUAL "sourcemap")
    # Source maps are emitted at link time, but object files still need debug info.
    list(APPEND compile_flags -O1)
  else()
    message(FATAL_ERROR "Unsupported WASM_DEBUG_MODE: ${WASM_DEBUG_MODE}")
  endif()

  resolve_wasm_debug_info_enabled(debug_info_enabled DEBUG_INFO "${WASM_COMPILE_DEBUG_INFO}")
  if(debug_info_enabled)
    get_wasm_debug_flag(debug_flag DEBUG_LEVEL "${WASM_COMPILE_DEBUG_LEVEL}")
    list(APPEND compile_flags "${debug_flag}")
  endif()

  if(WASM_COMPILE_EXTRA_FLAGS)
    list(APPEND compile_flags ${WASM_COMPILE_EXTRA_FLAGS})
  endif()

  set(${out_var} "${compile_flags}" PARENT_SCOPE)
endfunction()

function(get_wasm_link_flags out_var)
  set(options)
  set(oneValueArgs DEBUG_INFO DEBUG_LEVEL)
  cmake_parse_arguments(WASM_LINK "${options}" "${oneValueArgs}" "" ${ARGN})

  set(link_flags)

  if(WASM_DEBUG_MODE STREQUAL "release")
    list(APPEND link_flags -O2)
  elseif(WASM_DEBUG_MODE STREQUAL "dwarf")
    list(APPEND link_flags -O0)
  elseif(WASM_DEBUG_MODE STREQUAL "sourcemap")
    list(APPEND link_flags -O1)
  else()
    message(FATAL_ERROR "Unsupported WASM_DEBUG_MODE: ${WASM_DEBUG_MODE}")
  endif()

  resolve_wasm_debug_info_enabled(debug_info_enabled DEBUG_INFO "${WASM_LINK_DEBUG_INFO}")
  if(debug_info_enabled AND NOT WASM_DEBUG_MODE STREQUAL "sourcemap")
    get_wasm_debug_flag(debug_flag DEBUG_LEVEL "${WASM_LINK_DEBUG_LEVEL}")
    list(APPEND link_flags "${debug_flag}")
  endif()

  set(${out_var} "${link_flags}" PARENT_SCOPE)
endfunction()

function(apply_wasm_compile_options target)
  set(options)
  set(oneValueArgs DEBUG_INFO DEBUG_LEVEL)
  set(multiValueArgs EXTRA_FLAGS)
  cmake_parse_arguments(WASM_TARGET_COMPILE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT TARGET ${target})
    message(FATAL_ERROR "apply_wasm_compile_options: target '${target}' does not exist")
  endif()

  get_wasm_compile_flags(
    compile_flags
    DEBUG_INFO "${WASM_TARGET_COMPILE_DEBUG_INFO}"
    DEBUG_LEVEL "${WASM_TARGET_COMPILE_DEBUG_LEVEL}"
    EXTRA_FLAGS ${WASM_TARGET_COMPILE_EXTRA_FLAGS}
  )
  target_compile_options(${target} PRIVATE ${compile_flags})
endfunction()

function(create_wasm_debug_interface interface_target)
  set(options APPLY_LINK_OPTIONS)
  set(oneValueArgs PRESET DEBUG_INFO DEBUG_LEVEL)
  set(multiValueArgs EXTRA_FLAGS)
  cmake_parse_arguments(WASM_DEBUG_INTERFACE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(TARGET ${interface_target})
    message(FATAL_ERROR "create_wasm_debug_interface: target '${interface_target}' already exists")
  endif()

  resolve_wasm_debug_preset(
    preset_debug_info
    preset_debug_level
    PRESET "${WASM_DEBUG_INTERFACE_PRESET}"
  )

  set(effective_debug_info "${WASM_DEBUG_INTERFACE_DEBUG_INFO}")
  if("${effective_debug_info}" STREQUAL "" AND NOT "${preset_debug_info}" STREQUAL "")
    set(effective_debug_info "${preset_debug_info}")
  endif()

  set(effective_debug_level "${WASM_DEBUG_INTERFACE_DEBUG_LEVEL}")
  if("${effective_debug_level}" STREQUAL "" AND NOT "${preset_debug_level}" STREQUAL "")
    set(effective_debug_level "${preset_debug_level}")
  endif()

  add_library(${interface_target} INTERFACE)

  get_wasm_compile_flags(
    interface_compile_flags
    DEBUG_INFO "${effective_debug_info}"
    DEBUG_LEVEL "${effective_debug_level}"
    EXTRA_FLAGS ${WASM_DEBUG_INTERFACE_EXTRA_FLAGS}
  )
  target_compile_options(${interface_target} INTERFACE ${interface_compile_flags})

  if(WASM_DEBUG_INTERFACE_APPLY_LINK_OPTIONS)
    get_wasm_link_flags(
      interface_link_flags
      DEBUG_INFO "${effective_debug_info}"
      DEBUG_LEVEL "${effective_debug_level}"
    )
    target_link_options(${interface_target} INTERFACE ${interface_link_flags})
  endif()
endfunction()

function(attach_wasm_debug_interface interface_target)
  set(options)
  set(oneValueArgs VISIBILITY)
  set(multiValueArgs TARGETS)
  cmake_parse_arguments(WASM_ATTACH "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT TARGET ${interface_target})
    message(FATAL_ERROR "attach_wasm_debug_interface: interface target '${interface_target}' does not exist")
  endif()

  set(visibility PRIVATE)
  if(NOT "${WASM_ATTACH_VISIBILITY}" STREQUAL "")
    string(TOUPPER "${WASM_ATTACH_VISIBILITY}" visibility)
  endif()

  if(NOT visibility MATCHES "^(PRIVATE|PUBLIC|INTERFACE)$")
    message(FATAL_ERROR "attach_wasm_debug_interface: VISIBILITY must be PRIVATE, PUBLIC, or INTERFACE")
  endif()

  foreach(target IN LISTS WASM_ATTACH_TARGETS)
    if(NOT TARGET ${target})
      message(FATAL_ERROR "attach_wasm_debug_interface: target '${target}' does not exist")
    endif()
    target_link_libraries(${target} ${visibility} ${interface_target})
  endforeach()
endfunction()

function(configure_wasm_build target)
  set(options)
  set(oneValueArgs SOURCE_MAP SOURCE_MAP_TARGET_SEGMENT EXPORTED_FUNCTIONS EXPORTED_RUNTIME_METHODS OUTPUT_DIRECTORY TARGET_SUFFIX DEBUG_INFO DEBUG_LEVEL)
  set(multiValueArgs EXTRA_COMPILE_FLAGS)
  cmake_parse_arguments(WASM_BUILD "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

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

  apply_wasm_compile_options(
    ${target}
    DEBUG_INFO "${WASM_BUILD_DEBUG_INFO}"
    DEBUG_LEVEL "${WASM_BUILD_DEBUG_LEVEL}"
    EXTRA_FLAGS ${WASM_BUILD_EXTRA_COMPILE_FLAGS}
  )
  get_wasm_link_flags(
    link_flags
    DEBUG_INFO "${WASM_BUILD_DEBUG_INFO}"
    DEBUG_LEVEL "${WASM_BUILD_DEBUG_LEVEL}"
  )

  resolve_wasm_debug_info_enabled(debug_info_enabled DEBUG_INFO "${WASM_BUILD_DEBUG_INFO}")
  resolve_wasm_source_map_enabled(source_map_enabled SOURCE_MAP "${WASM_BUILD_SOURCE_MAP}")

  if(NOT "${WASM_BUILD_EXPORTED_FUNCTIONS}" STREQUAL "")
    list(APPEND link_flags "-sEXPORTED_FUNCTIONS=${WASM_BUILD_EXPORTED_FUNCTIONS}")
  endif()

  if(NOT "${WASM_BUILD_EXPORTED_RUNTIME_METHODS}" STREQUAL "")
    list(APPEND link_flags "-sEXPORTED_RUNTIME_METHODS=${WASM_BUILD_EXPORTED_RUNTIME_METHODS}")
  endif()

  target_link_options(${target} PRIVATE ${link_flags})

  if(source_map_enabled AND NOT "${source_map_target_segment}" STREQUAL "")
    configure_wasm_sourcemap(${target} "${source_map_target_segment}")
    if(NOT debug_info_enabled)
      message(STATUS "WASM source map for ${target} is enabled, but compile debug info is off; source-level mapping quality may be limited")
    endif()
  elseif(WASM_DEBUG_MODE STREQUAL "sourcemap" AND NOT source_map_enabled)
    message(STATUS "WASM source map disabled for ${target} because source map generation is off")
  endif()

  message(STATUS "WASM_OUTPUT_DIRECTORY(${target})=${output_directory}")
  set(js_output_path "${output_directory}/${target}${target_suffix}")
  set(wasm_output_path "${output_directory}/${target}.wasm")
  message(STATUS "WASM_JS_OUTPUT(${target})=${js_output_path}")
  message(STATUS "WASM_BINARY_OUTPUT(${target})=${wasm_output_path}")

  if(source_map_enabled)
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
  message(STATUS "WASM_DEBUG_INFO=${WASM_DEBUG_INFO}")
  message(STATUS "WASM_DEBUG_INFO_LEVEL=${WASM_DEBUG_INFO_LEVEL}")
  message(STATUS "WASM_SOURCE_MAP=${WASM_SOURCE_MAP}")
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
