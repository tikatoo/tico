cmake_minimum_required(VERSION 3.18.4)

project(tico VERSION 0.1.0
        LANGUAGES C)

include(CheckLanguage)
check_language(ASM)
check_language(ASM_NASM)

set(GAS OFF)
set(NASM OFF)
set(IMPL "unknown")

set(BUILD_EXAMPLES OFF CACHE BOOL "Include the examples directory")


### ASSEMBLER DETECTION ###

if(CMAKE_ASM_COMPILER)
    enable_language(ASM)
    message(STATUS "Assembler: ${CMAKE_ASM_COMPILER_ID} ${CMAKE_ASM_COMPILER_VERSION}")
    if(CMAKE_ASM_COMPILER_ID STREQUAL "GNU")
        set(GAS ON)
    elseif(CMAKE_ASM_COMPILER_ID STREQUAL "Clang")
        message(WARNING "Clang support not fully tested. Continuing expecting GCC behaviour.")
        set(GAS ON)
    endif()
endif()

if(CMAKE_ASM_NASM_COMPILER)
    enable_language(ASM_NASM)
    message(STATUS "Assembler: NASM ${CMAKE_ASM_NASM_COMPILER_VERSION}")
    set(NASM ON)
endif()

if(NOT GAS AND NOT NASM)
    message(SEND_ERROR "No assembler found")
endif()


### TARGET IMPLEMENTATION DETECTION ###

message(STATUS "Architecture: ${CMAKE_LIBRARY_ARCHITECTURE}")
if(CMAKE_LIBRARY_ARCHITECTURE STREQUAL "x86_64-linux-gnu")
    set(IMPL "x86_64-elf")
elseif(CMAKE_LIBRARY_ARCHITECTURE STREQUAL "aarch64-linux-gnu")
    set(IMPL "AArch64-elf")
endif()

message(STATUS "Implementation: ${IMPL}")
if(IMPL STREQUAL "unknown")
    message(SEND_ERROR "Target architecture not supported")
endif()


### Load implementation-specific build data ###

add_subdirectory(${IMPL})
target_include_directories(tico PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")


### Optionally, build examples (may be used for debugging) ###

if(BUILD_EXAMPLES)
    message(STATUS "Configuring examples")
    add_subdirectory(examples)
endif()
