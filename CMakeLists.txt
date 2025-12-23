cmake_minimum_required(VERSION 3.15)

# Protocol Buffers / Nanopb (Buf-driven) build

set(PROTO_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}/proto")
set(NANOPB_OUT_PATH "${CMAKE_CURRENT_LIST_DIR}/generated/nanopb")
set(BUF_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/buf.gen.yaml")

find_program(BUF_EXECUTABLE buf)
if(NOT BUF_EXECUTABLE)
    message(FATAL_ERROR "buf not found. Install buf and ensure it is on PATH.")
endif()

if(NOT EXISTS "${BUF_TEMPLATE}")
    message(FATAL_ERROR "Missing buf template: ${BUF_TEMPLATE}")
endif()

message(STATUS "Using buf: ${BUF_EXECUTABLE}")
message(STATUS "Using nanopb output path: ${NANOPB_OUT_PATH}")

# Nanopb runtime sources (always needed)
set(NANOPB_CORE_SRCS
    "${CMAKE_CURRENT_LIST_DIR}/nanopb/pb_common.c"
    "${CMAKE_CURRENT_LIST_DIR}/nanopb/pb_encode.c"
    "${CMAKE_CURRENT_LIST_DIR}/nanopb/pb_decode.c"
)

# Proto source files (organized by category)
file(GLOB_RECURSE PROTO_SRCS CONFIGURE_DEPENDS "${PROTO_BASE_DIR}/*.proto")

# Nanopb options files (affect codegen)
file(GLOB_RECURSE NANOPB_OPTIONS CONFIGURE_DEPENDS
    "${PROTO_BASE_DIR}/*.options"
)

# ---------------------------------------------------------------------------
# Configure-time codegen (ESP-IDF compatible)
#
# ESP-IDF can evaluate parts of the build graph during an "early expansion"
# phase. We must avoid executing side-effectful commands there.
#
# We still want configure-time codegen, but only when inputs change, so we keep
# a hash stamp in the build directory.
# ---------------------------------------------------------------------------

set(BUF_CODEGEN_STAMP "${CMAKE_CURRENT_BINARY_DIR}/buf_codegen.stamp")

if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    set(BUF_CODEGEN_INPUTS
        ${PROTO_SRCS}
        ${NANOPB_OPTIONS}
        "${CMAKE_CURRENT_LIST_DIR}/buf.yaml"
        "${CMAKE_CURRENT_LIST_DIR}/buf.gen.yaml"
    )

    set(_buf_hash_material "")
    foreach(_f IN LISTS BUF_CODEGEN_INPUTS)
        if(NOT EXISTS "${_f}")
            message(FATAL_ERROR "Missing buf codegen input: ${_f}")
        endif()
        file(SHA256 "${_f}" _f_sha)
        string(APPEND _buf_hash_material "${_f}|${_f_sha};")
    endforeach()
    string(SHA256 BUF_CODEGEN_HASH "${_buf_hash_material}")

    set(_run_buf_codegen TRUE)
    if(EXISTS "${BUF_CODEGEN_STAMP}")
        file(READ "${BUF_CODEGEN_STAMP}" _prev_hash)
        string(STRIP "${_prev_hash}" _prev_hash)
        if(_prev_hash STREQUAL BUF_CODEGEN_HASH)
            set(_run_buf_codegen FALSE)
        endif()
    endif()

    if(_run_buf_codegen)
        message(STATUS "Generating nanopb sources via buf (configure-time)")
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

        file(WRITE "${BUF_CODEGEN_STAMP}" "${BUF_CODEGEN_HASH}\n")
    else()
        message(STATUS "Nanopb sources up-to-date (buf codegen skipped)")
    endif()
endif()

# Generated nanopb sources (do not hardcode filenames)
# Note: re-glob after optional configure-time generation above.
file(GLOB_RECURSE NANOPB_GEN_SRCS CONFIGURE_DEPENDS
    "${NANOPB_OUT_PATH}/*.pb.c"
)

add_custom_target(protobufs_generate
    COMMAND "${BUF_EXECUTABLE}" generate --template "${BUF_TEMPLATE}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
    DEPENDS
        ${PROTO_SRCS}
        ${NANOPB_OPTIONS}
        "${CMAKE_CURRENT_LIST_DIR}/buf.yaml"
        "${CMAKE_CURRENT_LIST_DIR}/buf.gen.yaml"
    COMMENT "Generating nanopb sources via buf"
    VERBATIM
)

if(NOT NANOPB_GEN_SRCS)
    message(FATAL_ERROR
        "No generated nanopb sources found under ${NANOPB_OUT_PATH} after buf generate.\n"
        "Check your buf.gen.yaml and nanopb plugin installation."
    )
endif()

set(NANOPB_SRCS
    ${NANOPB_CORE_SRCS}
    ${NANOPB_GEN_SRCS}
)

add_library(protobufs STATIC ${NANOPB_SRCS})

target_include_directories(protobufs PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/nanopb
    ${NANOPB_OUT_PATH}
)
target_compile_definitions(protobufs PUBLIC PB_BUFFER_ONLY)
target_compile_definitions(protobufs PUBLIC PB_LITTLE_ENDIAN_8BIT)
target_compile_definitions(protobufs PUBLIC PB_NO_ERRMSG)

