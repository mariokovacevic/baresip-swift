cmake_minimum_required(VERSION 3.18)
project(BaresipKitCore C)

set(CMAKE_C_STANDARD 11)

find_package(libre CONFIG REQUIRED)

if(NOT BARESIP_INCLUDE_DIR)
  find_path(BARESIP_INCLUDE_DIR baresip.h PATH_SUFFIXES baresip)
endif()
if(NOT BARESIP_LIBRARY)
  find_library(BARESIP_LIBRARY baresip)
endif()
if(NOT BARESIP_INCLUDE_DIR OR NOT BARESIP_LIBRARY)
  message(FATAL_ERROR "baresip not found; set BARESIP_INCLUDE_DIR and BARESIP_LIBRARY")
endif()

add_library(baresipkitcore STATIC
  src/bsk_engine.c
  src/bsk_log.c
  src/bsk_account.c
  src/bsk_call.c
)

target_include_directories(baresipkitcore
  PUBLIC include
  PRIVATE ${BARESIP_INCLUDE_DIR}
)
target_compile_definitions(baresipkitcore PRIVATE ${BARESIPKIT_RE_DEFINITIONS})
target_compile_options(baresipkitcore PRIVATE -Wall -Wextra -Wshadow -Wno-unused-parameter)
target_link_libraries(baresipkitcore PUBLIC ${BARESIP_LIBRARY} libre::libre)

if(BARESIPKIT_EXTRA_LIBS)
  target_link_libraries(baresipkitcore PUBLIC ${BARESIPKIT_EXTRA_LIBS})
endif()

if(BARESIPKIT_BUILD_TESTS)
  enable_testing()
  add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../Tests/Core ${CMAKE_CURRENT_BINARY_DIR}/tests)
endif()
