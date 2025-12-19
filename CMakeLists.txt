cmake_minimum_required(VERSION 3.15)

project(protobufs C CXX)

# Protocol Buffers / Nanopb (Buf-driven) build

set(PROTO_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}/proto")
set(NANOPB_OUT_PATH "${CMAKE_CURRENT_LIST_DIR}/generated/nanopb")
set(BUF_TEMPLATE "${CMAKE_CURRENT_LIST_DIR}/buf.gen.yaml")

find_program(BUF_EXECUTABLE buf)
if(NOT BUF_EXECUTABLE)
    message(FATAL_ERROR "buf not found. Install buf and ensure it is on PATH.")
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

# Generated nanopb sources (do not hardcode filenames)
file(GLOB_RECURSE NANOPB_GEN_SRCS CONFIGURE_DEPENDS
    "${NANOPB_OUT_PATH}/*.pb.c"
    "${NANOPB_OUT_PATH}/*/*.pb.c"
    "${NANOPB_OUT_PATH}/*/*/*.pb.c"
)

# Ensure nanopb code exists at configure time (so the build has sources).
# This does not hardcode any generated filenames and keeps CMake stable across proto renames.
if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    if(NOT EXISTS "${BUF_TEMPLATE}")
        message(FATAL_ERROR "Missing buf template: ${BUF_TEMPLATE}")
    endif()

    if(NOT NANOPB_GEN_SRCS)
        message(STATUS "No generated nanopb sources found; running 'buf generate'...")
        execute_process(
            COMMAND "${BUF_EXECUTABLE}" generate --template "${BUF_TEMPLATE}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}"
            RESULT_VARIABLE BUF_GENERATE_RESULT
        )
        if(NOT BUF_GENERATE_RESULT EQUAL 0)
            message(FATAL_ERROR "buf generate failed with exit code ${BUF_GENERATE_RESULT}")
        endif()

        # Re-scan after generation.
        file(GLOB_RECURSE NANOPB_GEN_SRCS CONFIGURE_DEPENDS
            "${NANOPB_OUT_PATH}/*.pb.c"
            "${NANOPB_OUT_PATH}/*/*.pb.c"
            "${NANOPB_OUT_PATH}/*/*/*.pb.c"
        )

        if(NOT NANOPB_GEN_SRCS)
            message(FATAL_ERROR "buf generate produced no nanopb .pb.c files under ${NANOPB_OUT_PATH}")
        endif()
    endif()

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
endif()

set(NANOPB_SRCS
    ${NANOPB_CORE_SRCS}
    ${NANOPB_GEN_SRCS}
)

add_library(protobufs STATIC ${NANOPB_SRCS})
if(TARGET protobufs_generate)
    add_dependencies(protobufs protobufs_generate)
endif()
target_include_directories(protobufs PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/nanopb
    ${NANOPB_OUT_PATH}
)
target_compile_definitions(protobufs PUBLIC PB_BUFFER_ONLY)
target_compile_definitions(protobufs PUBLIC PB_LITTLE_ENDIAN_8BIT)
target_compile_definitions(protobufs PUBLIC PB_NO_ERRMSG)

