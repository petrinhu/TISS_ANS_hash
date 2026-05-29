# CMakeLists.txt - port C++ da tiss-hash.
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
#   - pugixml (>= 1.10 recomendado; fetch automatico se ausente)
#   - openssl (libcrypto)
#   - cmake >= 3.20
#   - C++20 compiler (gcc >= 13, clang >= 16)
#   - python3 (so pra regenerar tests/test_vectors.hpp)

cmake_minimum_required(VERSION 3.20)
project(tiss_hash_cpp
    VERSION 0.1.0
    DESCRIPTION "Hash MD5 do epilogo XML TISS/ANS (Padrao TISS) - C++ port"
    HOMEPAGE_URL "https://github.com/petrinhu/TISS_ANS_hash"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Default Release pra builds sem -DCMAKE_BUILD_TYPE.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# ----------------------------------------------------------------------------
# Dependencias
# ----------------------------------------------------------------------------

find_package(OpenSSL REQUIRED COMPONENTS Crypto)

# pugixml: preferir pacote do sistema (Fedora: pugixml-devel; Debian:
# libpugixml-dev). Fallback pra FetchContent se ausente.
find_package(pugixml CONFIG QUIET)
if(NOT pugixml_FOUND)
    message(STATUS "pugixml nao encontrado via find_package; usando FetchContent")
    include(FetchContent)
    FetchContent_Declare(
        pugixml
        GIT_REPOSITORY https://github.com/zeux/pugixml.git
        GIT_TAG v1.14)
    FetchContent_MakeAvailable(pugixml)
else()
    message(STATUS "pugixml: ${pugixml_VERSION} (find_package)")
endif()

# ----------------------------------------------------------------------------
# Biblioteca
# ----------------------------------------------------------------------------

add_library(tiss_hash_cpp src/tiss_hash.cpp)
add_library(tiss_hash::cpp ALIAS tiss_hash_cpp)

target_include_directories(tiss_hash_cpp PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>)

target_link_libraries(tiss_hash_cpp
    PUBLIC OpenSSL::Crypto pugixml::pugixml)

if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    target_compile_options(tiss_hash_cpp PRIVATE
        -Wall -Wextra -Wpedantic -Werror
        -Wshadow -Wconversion -Wsign-conversion
        -Wnon-virtual-dtor -Wold-style-cast -Wcast-align
        -Wnull-dereference -Wdouble-promotion -Wformat=2)
endif()

set_target_properties(tiss_hash_cpp PROPERTIES
    VERSION   ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
    POSITION_INDEPENDENT_CODE ON)

# ----------------------------------------------------------------------------
# Testes
# ----------------------------------------------------------------------------

option(TISS_HASH_CPP_BUILD_TESTS "Build conformance tests" ON)

if(TISS_HASH_CPP_BUILD_TESTS)
    enable_testing()

    find_package(Python3 COMPONENTS Interpreter REQUIRED)

    set(REPO_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
    set(VECTORS_JSON "${REPO_ROOT}/conformance/vectors.json")
    set(INPUTS_DIR "${REPO_ROOT}/conformance/inputs")
    set(GEN_SCRIPT "${CMAKE_CURRENT_SOURCE_DIR}/tools/gen_test_vectors.py")
    set(VECTORS_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/tests/test_vectors.hpp")

    # Re-gera test_vectors.hpp se vectors.json mudar.
    add_custom_command(
        OUTPUT  ${VECTORS_HEADER}
        COMMAND ${Python3_EXECUTABLE} ${GEN_SCRIPT}
                ${VECTORS_JSON} ${VECTORS_HEADER}
        DEPENDS ${VECTORS_JSON} ${GEN_SCRIPT}
        COMMENT "Regenerating tests/test_vectors.hpp from vectors.json"
        VERBATIM)
    add_custom_target(tiss_hash_cpp_gen_vectors DEPENDS ${VECTORS_HEADER})

    add_executable(test_conformance tests/test_conformance.cpp ${VECTORS_HEADER})
    add_dependencies(test_conformance tiss_hash_cpp_gen_vectors)
    # doctest.h vai como SYSTEM: compiladores e clang-tidy ignoram seus
    # avisos (a lib vendorizada nao e nosso codigo).
    target_include_directories(test_conformance SYSTEM PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/third_party)
    target_include_directories(test_conformance PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/tests)
    target_link_libraries(test_conformance PRIVATE tiss_hash_cpp)

    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
        # doctest.h tem alguns avisos com -Wconversion / -Wold-style-cast;
        # mantemos -Werror, mas silencia o que nao e nosso codigo.
        target_compile_options(test_conformance PRIVATE
            -Wall -Wextra -Wpedantic)
    endif()

    add_test(
        NAME conformance
        COMMAND test_conformance --inputs ${INPUTS_DIR})

    # Belt-and-suspenders (A-CI5): alem do --inputs, expor o dir absoluto via
    # env. O runner resolve --inputs > TISS_CONFORMANCE_DIR > TISS_INPUTS_DIR
    # > default; assim o teste acha os inputs mesmo rodado fora do CWD do build.
    set_tests_properties(conformance PROPERTIES
        ENVIRONMENT "TISS_CONFORMANCE_DIR=${INPUTS_DIR}")
endif()

# ----------------------------------------------------------------------------
# Install + pkg-config + CMake package
# ----------------------------------------------------------------------------

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

install(TARGETS tiss_hash_cpp
    EXPORT  tiss_hash_cpp-targets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(DIRECTORY include/tiss_hash
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

install(EXPORT tiss_hash_cpp-targets
    FILE        tiss_hash_cppTargets.cmake
    NAMESPACE   tiss_hash::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/tiss_hash_cpp)

# pkg-config file
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/tiss-hash-cpp.pc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/tiss-hash-cpp.pc"
    @ONLY)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/tiss-hash-cpp.pc"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)

# CMake package config: permite find_package(tiss_hash_cpp) em consumers.
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/tiss_hash_cppConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/tiss_hash_cppConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/tiss_hash_cppConfig.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/tiss_hash_cpp)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/tiss_hash_cppConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/tiss_hash_cppConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/tiss_hash_cpp)
