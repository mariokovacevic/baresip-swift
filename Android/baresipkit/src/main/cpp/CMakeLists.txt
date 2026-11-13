cmake_minimum_required(VERSION 3.22)
project(baresipkit_jni C)

set(BSK_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../../../..")
if(ANDROID)
  set(BSK_SLICE "android-${ANDROID_ABI}")
  set(BSK_PLATFORM "android")
else()
  set(BSK_SLICE "host")
  set(BSK_PLATFORM "host")
endif()
set(BSK_CORE "${BSK_ROOT}/Build/out/${BSK_SLICE}/lib/libBaresipKitCore.a")
if(NOT EXISTS "${BSK_CORE}")
  message(FATAL_ERROR "${BSK_CORE} is missing. Build the core first: PLATFORM=${BSK_PLATFORM} Build/build-xcframework.sh")
endif()

add_library(BaresipKitCore STATIC IMPORTED)
set_target_properties(BaresipKitCore PROPERTIES
  IMPORTED_LOCATION "${BSK_CORE}"
  INTERFACE_INCLUDE_DIRECTORIES "${BSK_ROOT}/Core/include")

add_library(baresipkit SHARED bsk_jni.c bsk_jni_api.c bsk_jni_video.c)
target_compile_options(baresipkit PRIVATE -Wall -Wextra -Werror)
target_link_options(baresipkit PRIVATE "-Wl,--exclude-libs,ALL" "-Wl,--gc-sections" "-Wl,--no-undefined")

if(ANDROID)
  target_link_libraries(baresipkit PRIVATE BaresipKitCore aaudio mediandk log z m)
else()
  find_package(JNI REQUIRED)
  target_include_directories(baresipkit PRIVATE ${JNI_INCLUDE_DIRS})
  find_package(Threads REQUIRED)
  target_link_libraries(baresipkit PRIVATE BaresipKitCore Threads::Threads z m dl)
endif()
