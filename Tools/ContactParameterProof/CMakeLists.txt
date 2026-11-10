cmake_minimum_required(VERSION 3.18)
project(contact_proof C)

find_package(libre CONFIG REQUIRED)

add_executable(contact_proof contact_proof.c)
target_link_libraries(contact_proof PRIVATE libre::libre)
target_compile_definitions(contact_proof PRIVATE HAVE_UNIXSOCK=0)
