add_library(cmake_core STATIC
  core/accumulator.cc
)

target_include_directories(cmake_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

add_library(cmake_platform STATIC
  platform/log_sink.cc
)

target_include_directories(cmake_platform PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

add_library(cmake_domain STATIC
  domain/simulation.cc
  domain/report.cc
)

target_include_directories(cmake_domain PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(cmake_domain PUBLIC cmake_core cmake_platform)

attach_wasm_debug_interface(
  cmake_project_debug_info
  TARGETS cmake_core cmake_platform cmake_domain
)

add_executable(cmake_demo
  app/main.cc
)

target_link_libraries(cmake_demo PRIVATE cmake_domain)

add_executable(cmake_tools_demo
  app/tools_main.cc
)

target_link_libraries(cmake_tools_demo PRIVATE cmake_domain)
