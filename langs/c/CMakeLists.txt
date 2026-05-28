# CMakeLists.txt - port C da tiss-hash.
#
# Build:
#   cmake -B build -S .
#   cmake --build build -j
#   ctest --test-dir build --output-on-failure
#
# Install (PREFIX padrao /usr/local):
#   cmake --install build
#
# Deps de sistema:
#   - libxml2 (libxml2-devel / libxml2-dev)
#   - openssl (openssl-devel / libssl-dev)
#   - cmake >= 3.16
#   - C11 compiler (gcc >= 5 ou clang >= 3.5)
#   - python3 (so pra regenerar tests/test_vectors.h)

cmake_minimum_required(VERSION 3.16)
project(tiss_hash
    VERSION 0.1.0
    DESCRIPTION "Hash MD5 do epilogo XML TISS/ANS (Padrao TISS 4.01.00)"
    HOMEPAGE_URL "https://github.com/petrinhu/TISS_ANS_hash"
    LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Default Release pra builds sem -DCMAKE_BUILD_TYPE.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# ----------------------------------------------------------------------------
# Dependencias
# ----------------------------------------------------------------------------

find_package(LibXml2 REQUIRED)
find_package(OpenSSL REQUIRED COMPONENTS Crypto)
find_package(Threads REQUIRED)  # pthread (pra pthread_once)

# ----------------------------------------------------------------------------
# Biblioteca
# ----------------------------------------------------------------------------

add_library(tiss_hash src/tiss_hash.c)
add_library(tiss_hash::tiss_hash ALIAS tiss_hash)

target_include_directories(tiss_hash PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>)

target_link_libraries(tiss_hash
    PUBLIC LibXml2::LibXml2 OpenSSL::Crypto
    PRIVATE Threads::Threads)

# Strict flags em todos compiladores GCC-like.
if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(tiss_hash PRIVATE
        -Wall
        -Wextra
        -Wpedantic
        -Werror
        -Wstrict-prototypes
        -Wmissing-prototypes
        -Wshadow
        -Wpointer-arith
        -Wcast-qual
        -Wwrite-strings
        -Wundef
        -Wno-deprecated-declarations  # silencia macros legacy em headers OpenSSL 3.x
    )
endif()

set_target_properties(tiss_hash PROPERTIES
    VERSION   ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    PUBLIC_HEADER include/tiss_hash.h
    POSITION_INDEPENDENT_CODE ON)

# ----------------------------------------------------------------------------
# Testes
# ----------------------------------------------------------------------------

option(TISS_HASH_BUILD_TESTS "Build conformance tests" ON)

if(TISS_HASH_BUILD_TESTS)
    enable_testing()

    # Caminho ate o repo root (langs/c/ -> ../..).
    set(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
    set(VECTORS_JSON "${REPO_ROOT}/conformance/vectors.json")
    set(INPUTS_DIR "${REPO_ROOT}/conformance/inputs")
    set(GEN_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/tools/gen_test_vectors.py")
    set(VECTORS_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_vectors.h")

    find_package(Python3 COMPONENTS Interpreter REQUIRED)

    # Re-gera test_vectors.h se vectors.json mudar.
    add_custom_command(
        OUTPUT  ${VECTORS_HEADER}
        COMMAND ${Python3_EXECUTABLE} ${GEN_SCRIPT}
                --out ${VECTORS_HEADER}
        DEPENDS ${VECTORS_JSON} ${GEN_SCRIPT}
        COMMENT "Regenerating tests/test_vectors.h from vectors.json"
        VERBATIM)
    add_custom_target(tiss_hash_gen_vectors DEPENDS ${VECTORS_HEADER})

    add_executable(test_conformance tests/test_conformance.c ${VECTORS_HEADER})
    add_dependencies(test_conformance tiss_hash_gen_vectors)
    target_include_directories(test_conformance PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/tests)
    target_link_libraries(test_conformance PRIVATE tiss_hash)

    if(CMAKE_C_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
        target_compile_options(test_conformance PRIVATE
            -Wall -Wextra -Wpedantic -Werror)
    endif()

    add_test(
        NAME conformance
        COMMAND test_conformance ${INPUTS_DIR})
endif()

# ----------------------------------------------------------------------------
# Install + pkg-config + CMake package
# ----------------------------------------------------------------------------

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(TARGETS tiss_hash
    EXPORT  tiss_hash-targets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(EXPORT tiss_hash-targets
    FILE        tiss_hashTargets.cmake
    NAMESPACE   tiss_hash::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/tiss_hash)

# pkg-config file
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/tiss-hash.pc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/tiss-hash.pc"
    @ONLY)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/tiss-hash.pc"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)

# CMake package config: permite find_package(tiss_hash) em consumers.
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/tiss_hashConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/tiss_hashConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/tiss_hashConfig.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/tiss_hash)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/tiss_hashConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/tiss_hashConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/tiss_hash)
