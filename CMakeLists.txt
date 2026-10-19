cmake_minimum_required(VERSION 3.16)

project(cs211_lab2 LANGUAGES C)

option(LAB_USE_SYSTEM_BLAS
       "Use an installed OpenBLAS/CBLAS instead of the bundled reference backend"
       OFF)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# The starter src/mygemm.c intentionally contains empty function bodies. Avoid a
# wall of unused-parameter warnings before students begin their implementation.
if(NOT MSVC)
    set_source_files_properties(src/mygemm.c PROPERTIES
        COMPILE_OPTIONS -Wno-unused-parameter)
endif()

if(LAB_USE_SYSTEM_BLAS)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(OPENBLAS QUIET IMPORTED_TARGET openblas)
    endif()

    if(TARGET PkgConfig::OPENBLAS)
        add_library(lab_blas INTERFACE)
        target_link_libraries(lab_blas INTERFACE PkgConfig::OPENBLAS)
    else()
        find_path(CBLAS_INCLUDE_DIR
                  NAMES cblas.h
                  PATH_SUFFIXES openblas openblas-pthread openblas-openmp)
        find_library(CBLAS_LIBRARY NAMES openblas cblas)
        if(NOT CBLAS_INCLUDE_DIR OR NOT CBLAS_LIBRARY)
            message(FATAL_ERROR
                "LAB_USE_SYSTEM_BLAS=ON, but CBLAS/OpenBLAS was not found. "
                "Configure without this option to use the bundled backend.")
        endif()
        add_library(lab_blas INTERFACE)
        target_include_directories(lab_blas INTERFACE "${CBLAS_INCLUDE_DIR}")
        target_link_libraries(lab_blas INTERFACE "${CBLAS_LIBRARY}")
    endif()
else()
    add_library(lab_blas STATIC
        third_party/labblas/src/cblas.c)
    target_include_directories(lab_blas PUBLIC
        "${CMAKE_CURRENT_SOURCE_DIR}/third_party/labblas/include")
    target_compile_features(lab_blas PUBLIC c_std_11)

    # The reference result is not part of the measured student time. Compile
    # it efficiently so correctness checking does not dominate each run.
    if(MSVC)
        target_compile_options(lab_blas PRIVATE /O2 /W4)
    else()
        target_compile_options(lab_blas PRIVATE -O3 -Wall -Wextra -Wpedantic)
    endif()
endif()

function(add_lab_executable target driver)
    add_executable(${target}
        ${driver}
        src/util.c
        src/mygemm.c)
    target_include_directories(${target} PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/include")
    target_link_libraries(${target} PRIVATE lab_blas)
    if(NOT MSVC)
        target_link_libraries(${target} PRIVATE m)
    endif()
    if(MSVC)
        target_compile_options(${target} PRIVATE /W4)
    else()
        target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)
    endif()
    if(UNIX)
        target_compile_definitions(${target} PRIVATE _POSIX_C_SOURCE=200809L)
    endif()
endfunction()

add_lab_executable(reg_reuse benchmarks/reg_reuse.c)
add_lab_executable(cache_part3 benchmarks/cache_part3.c)
add_lab_executable(cache_part4_o0 benchmarks/cache_part4.c)
add_lab_executable(cache_part4_o1 benchmarks/cache_part4.c)
add_lab_executable(cache_part4_o2 benchmarks/cache_part4.c)
add_lab_executable(cache_part4_o3 benchmarks/cache_part4.c)

if(MSVC)
    target_compile_options(reg_reuse PRIVATE /Od)
    target_compile_options(cache_part3 PRIVATE /Od)
    target_compile_options(cache_part4_o0 PRIVATE /Od)
    target_compile_options(cache_part4_o1 PRIVATE /O1)
    target_compile_options(cache_part4_o2 PRIVATE /O2)
    # MSVC has no separate /O3; /O2 is its maximum speed preset.
    target_compile_options(cache_part4_o3 PRIVATE /O2)
else()
    target_compile_options(reg_reuse PRIVATE -O0)
    target_compile_options(cache_part3 PRIVATE -O0)
    target_compile_options(cache_part4_o0 PRIVATE -O0)
    target_compile_options(cache_part4_o1 PRIVATE -O1)
    target_compile_options(cache_part4_o2 PRIVATE -O2)
    target_compile_options(cache_part4_o3 PRIVATE -O3)
endif()

message(STATUS "System BLAS requested: ${LAB_USE_SYSTEM_BLAS}")
if(NOT LAB_USE_SYSTEM_BLAS)
    message(STATUS "Using bundled portable cblas_dgemm reference backend")
endif()

include(CTest)
if(BUILD_TESTING)
    add_executable(labblas_selftest tests/labblas_selftest.c)
    target_link_libraries(labblas_selftest PRIVATE lab_blas)
    if(NOT MSVC)
        target_link_libraries(labblas_selftest PRIVATE m)
    endif()
    add_test(NAME bundled_blas_reference COMMAND labblas_selftest)

    add_executable(framework_util_selftest
        tests/framework_util_selftest.c
        src/util.c)
    target_include_directories(framework_util_selftest PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/include")
    target_link_libraries(framework_util_selftest PRIVATE lab_blas)
    if(NOT MSVC)
        target_link_libraries(framework_util_selftest PRIVATE m)
    endif()
    if(UNIX)
        target_compile_definitions(framework_util_selftest PRIVATE
            _POSIX_C_SOURCE=200809L)
    endif()
    add_test(NAME framework_correctness_pipeline COMMAND framework_util_selftest)
endif()

# Optional Bonus driver, independent of the student's basic src/mygemm.c.
option(LAB_BUILD_BONUS "Build the single-thread Bonus benchmark" OFF)
option(LAB_BONUS_NATIVE "Use -march=native for the Bonus and bundled BLAS" OFF)
if(LAB_BUILD_BONUS)
    add_subdirectory(bonus)
endif()
