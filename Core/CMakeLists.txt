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

set(BSK_SOURCES
  src/bsk_engine.c
  src/bsk_engine_control.c
  src/bsk_config.c
  src/bsk_status.c
  src/bsk_log.c
  src/bsk_account.c
  src/bsk_call.c
  src/bsk_call_media.c
  src/bsk_call_ops.c
  src/bsk_video.c
  src/bsk_tls.c
  src/bsk_rate.c
  src/bsk_message.c
  src/bsk_record.c
  src/bsk_audio.c
  src/bsk_g722.c
  src/bsk_h264.c
  third_party/g722/g722_encode.c
  third_party/g722/g722_decode.c
)

if(APPLE)
  enable_language(OBJC)
  list(APPEND BSK_SOURCES src/apple/vidtoolbox.c src/apple/bskcapture.m src/apple/bsk_trust.c)
  set_source_files_properties(src/apple/bskcapture.m PROPERTIES COMPILE_FLAGS "-fobjc-arc")
endif()

add_library(baresipkitcore STATIC ${BSK_SOURCES})

target_include_directories(baresipkitcore
  PUBLIC include
  PRIVATE src/apple third_party/g722
)
target_include_directories(baresipkitcore SYSTEM
  PRIVATE ${BARESIP_INCLUDE_DIR} ${OPENSSL_INCLUDE_DIR}
)
if(APPLE)
  target_compile_definitions(baresipkitcore PRIVATE BSK_HAVE_APPLE_VIDEO=1)
  target_link_libraries(baresipkitcore PUBLIC
    "-framework AVFoundation" "-framework CoreMedia" "-framework CoreVideo"
    "-framework VideoToolbox" "-framework Foundation"
    "-framework Security" "-framework CoreFoundation")
endif()
include(CheckFunctionExists)
include(CheckIncludeFile)
check_function_exists(thrd_create BSK_HAVE_THREADS_FUN)
check_include_file(threads.h BSK_HAVE_THREADS_H)
if(BSK_HAVE_THREADS_FUN AND BSK_HAVE_THREADS_H)
  target_compile_definitions(baresipkitcore PRIVATE HAVE_THREADS)
endif()
target_compile_options(baresipkitcore PRIVATE -Wall -Wextra -Wshadow -Werror)
# Vendored code is kept unchanged; do not fail its build on warnings.
set_source_files_properties(third_party/g722/g722_encode.c third_party/g722/g722_decode.c
  PROPERTIES COMPILE_OPTIONS "-Wno-error;-w")
target_link_libraries(baresipkitcore PUBLIC ${BARESIP_LIBRARY} libre::libre)

if(BARESIPKIT_EXTRA_LIBS)
  target_link_libraries(baresipkitcore PUBLIC ${BARESIPKIT_EXTRA_LIBS})
endif()

if(BARESIPKIT_BUILD_TESTS)
  enable_testing()
  add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../Tests/Core ${CMAKE_CURRENT_BINARY_DIR}/tests)
endif()
