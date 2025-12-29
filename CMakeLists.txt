cmake_minimum_required(VERSION 3.15)

# Protocol Buffers / protobuf-c (Buf-driven) build

set(PROTO_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}/proto")
set(PROTOBUF_C_OUT_PATH "${CMAKE_CURRENT_LIST_DIR}/generated/protobuf-c")
set(BUF_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/buf.gen.yaml")

find_program(BUF_EXECUTABLE buf)
if(NOT BUF_EXECUTABLE)
    message(FATAL_ERROR "buf not found. Install buf and ensure it is on PATH.")
endif()

if(NOT EXISTS "${BUF_TEMPLATE}")
    message(FATAL_ERROR "Missing buf template: ${BUF_TEMPLATE}")
endif()

message(STATUS "Using buf: ${BUF_EXECUTABLE}")
message(STATUS "Using protobuf-c output path: ${PROTOBUF_C_OUT_PATH}")

# Helper to keep CONFIGURE_DEPENDS out of script-mode invocations triggered by
# ESP-IDF's requirement scanner.
function(_glob_recurse_optional OUT_VAR)
    if(CMAKE_SCRIPT_MODE_FILE OR CMAKE_BUILD_EARLY_EXPANSION)
        file(GLOB_RECURSE _tmp ${ARGN})
    else()
        file(GLOB_RECURSE _tmp CONFIGURE_DEPENDS ${ARGN})
    endif()
    set(${OUT_VAR} "${_tmp}" PARENT_SCOPE)
endfunction()

# Proto source files (organized by category)
_glob_recurse_optional(PROTO_SRCS "${PROTO_BASE_DIR}/*.proto")

# ---------------------------------------------------------------------------
# Configure-time codegen (ESP-IDF compatible)
#
# ESP-IDF can evaluate parts of the build graph during an "early expansion"
# phase. We must avoid executing side-effectful commands there.
#
# Always regenerate on every configure to ensure CI builds work correctly.
# ---------------------------------------------------------------------------

if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    message(STATUS "Generating protobuf-c sources via buf (configure-time)")
    execute_process(
        COMMAND "${BUF_EXECUTABLE}" generate --template "${BUF_TEMPLATE}"
        WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
        RESULT_VARIABLE BUF_GEN_RESULT
        OUTPUT_VARIABLE BUF_GEN_STDOUT
        ERROR_VARIABLE BUF_GEN_STDERR
    )

    if(NOT BUF_GEN_RESULT EQUAL 0)
        message(FATAL_ERROR
            "buf generate failed with exit code ${BUF_GEN_RESULT}.\n"
            "stdout:\n${BUF_GEN_STDOUT}\n"
            "stderr:\n${BUF_GEN_STDERR}\n"
        )
    endif()
endif()

# Generated protobuf-c sources (do not hardcode filenames)
# Note: re-glob after configure-time generation above.
_glob_recurse_optional(PROTOBUF_C_GEN_SRCS "${PROTOBUF_C_OUT_PATH}/*.pb-c.c")

if(NOT CMAKE_SCRIPT_MODE_FILE AND NOT CMAKE_BUILD_EARLY_EXPANSION)
    add_custom_target(protobufs_generate
        COMMAND "${BUF_EXECUTABLE}" generate --template "${BUF_TEMPLATE}"
        WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
        DEPENDS
            ${PROTO_SRCS}
            "${CMAKE_CURRENT_LIST_DIR}/buf.yaml"
            "${CMAKE_CURRENT_LIST_DIR}/buf.gen.yaml"
        COMMENT "Generating protobuf-c sources via buf"
        VERBATIM
    )
endif()

if(NOT PROTOBUF_C_GEN_SRCS)
    if(CMAKE_SCRIPT_MODE_FILE OR CMAKE_BUILD_EARLY_EXPANSION)
        message(STATUS "Skipping protobuf-c source validation during ESP-IDF requirement scan")
    else()
        message(FATAL_ERROR
            "No generated protobuf-c sources found under ${PROTOBUF_C_OUT_PATH} after buf generate.\n"
            "Check your buf.gen.yaml and protobuf-c plugin (protoc-gen-c) installation."
        )
    endif()
endif()

set(PROTOBUF_C_GEN_SRCS
    ${PROTOBUF_C_GEN_SRCS}
)

set(PROTOBUF_C_GEN_INCLUDE_DIRS
    ${PROTOBUF_C_OUT_PATH}
)
foreach(_protobuf_c_src IN LISTS PROTOBUF_C_GEN_SRCS)
    get_filename_component(_protobuf_c_dir "${_protobuf_c_src}" DIRECTORY)
    list(APPEND PROTOBUF_C_GEN_INCLUDE_DIRS "${_protobuf_c_dir}")
endforeach()
list(REMOVE_DUPLICATES PROTOBUF_C_GEN_INCLUDE_DIRS)

if(COMMAND idf_component_register)
    idf_component_register(
        SRCS ${PROTOBUF_C_GEN_SRCS}
        INCLUDE_DIRS ${PROTOBUF_C_GEN_INCLUDE_DIRS}
        REQUIRES protobuf-c
    )
    set(_PROTOBUF_TARGET ${COMPONENT_LIB})
else()
    add_library(protobufs STATIC ${PROTOBUF_C_GEN_SRCS})
    target_include_directories(protobufs PUBLIC ${PROTOBUF_C_GEN_INCLUDE_DIRS})
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(PROTOBUF_C QUIET protobuf-c)
    endif()
    if(PROTOBUF_C_FOUND)
        target_include_directories(protobufs PUBLIC ${PROTOBUF_C_INCLUDE_DIRS})
        target_link_libraries(protobufs PUBLIC ${PROTOBUF_C_LIBRARIES})
        target_compile_options(protobufs PUBLIC ${PROTOBUF_C_CFLAGS_OTHER})
    else()
        find_library(PROTOBUF_C_LIB protobuf-c)
        find_path(PROTOBUF_C_INC protobuf-c/protobuf-c.h)
        if(PROTOBUF_C_LIB AND PROTOBUF_C_INC)
            target_include_directories(protobufs PUBLIC ${PROTOBUF_C_INC})
            target_link_libraries(protobufs PUBLIC ${PROTOBUF_C_LIB})
        endif()
    endif()
    set(_PROTOBUF_TARGET protobufs)
endif()
