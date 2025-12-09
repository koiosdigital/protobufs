cmake_minimum_required(VERSION 3.15)

# Protocol Buffers Generation Configuration
set(PROTO_COMPILER "protoc")
set(PROTO_BASE_DIR "${CMAKE_CURRENT_LIST_DIR}/proto")

# Support both old (nanopb/) and new (generated/nanopb/) output paths
# for backward compatibility during migration
if(EXISTS "${CMAKE_CURRENT_LIST_DIR}/nanopb")
    set(NANOPB_OUT_PATH "${CMAKE_CURRENT_LIST_DIR}/nanopb")
    message(STATUS "Using legacy nanopb output path: ${NANOPB_OUT_PATH}")
else()
    set(NANOPB_OUT_PATH "${CMAKE_CURRENT_LIST_DIR}/generated/nanopb")
    message(STATUS "Using new nanopb output path: ${NANOPB_OUT_PATH}")
endif()

# Nanopb core sources (always needed)
set(NANOPB_CORE_SRCS
    "${NANOPB_OUT_PATH}/pb_common.c"
    "${NANOPB_OUT_PATH}/pb_encode.c"
    "${NANOPB_OUT_PATH}/pb_decode.c"
)

# Common proto-generated sources
set(NANOPB_COMMON_SRCS
    "${NANOPB_OUT_PATH}/common/enums.pb.c"
    "${NANOPB_OUT_PATH}/common/types.pb.c"
)

# Core proto-generated sources
set(NANOPB_CORE_PROTO_SRCS
    "${NANOPB_OUT_PATH}/core/routing.pb.c"
    "${NANOPB_OUT_PATH}/core/system.pb.c"
    "${NANOPB_OUT_PATH}/core/heartbeat.pb.c"
)

# Service proto-generated sources
set(NANOPB_SERVICE_SRCS
    "${NANOPB_OUT_PATH}/services/discovery.pb.c"
    "${NANOPB_OUT_PATH}/services/firmware_update.pb.c"
)

# Device proto-generated sources
set(NANOPB_DEVICE_SRCS
    "${NANOPB_OUT_PATH}/devices/device_adc.pb.c"
    "${NANOPB_OUT_PATH}/devices/device_efc.pb.c"
    "${NANOPB_OUT_PATH}/devices/device_vfd.pb.c"
    "${NANOPB_OUT_PATH}/devices/device_rover.pb.c"
)

# All generated sources
set(NANOPB_SRCS
    ${NANOPB_CORE_SRCS}
    ${NANOPB_COMMON_SRCS}
    ${NANOPB_CORE_PROTO_SRCS}
    ${NANOPB_SERVICE_SRCS}
    ${NANOPB_DEVICE_SRCS}
)

# Proto source files (organized by category)
file(GLOB PROTO_COMMON_SRCS "${PROTO_BASE_DIR}/common/*.proto")
file(GLOB PROTO_CORE_SRCS "${PROTO_BASE_DIR}/core/*.proto")
file(GLOB PROTO_SERVICE_SRCS "${PROTO_BASE_DIR}/services/*.proto")
file(GLOB PROTO_DEVICE_SRCS "${PROTO_BASE_DIR}/devices/*.proto")

set(PROTO_SRCS
    ${PROTO_COMMON_SRCS}
    ${PROTO_CORE_SRCS}
    ${PROTO_SERVICE_SRCS}
    ${PROTO_DEVICE_SRCS}
)

# Generate nanopb code if not in early expansion phase
if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    file(MAKE_DIRECTORY ${NANOPB_OUT_PATH})
    file(MAKE_DIRECTORY ${NANOPB_OUT_PATH}/common)
    file(MAKE_DIRECTORY ${NANOPB_OUT_PATH}/core)
    file(MAKE_DIRECTORY ${NANOPB_OUT_PATH}/services)
    file(MAKE_DIRECTORY ${NANOPB_OUT_PATH}/devices)
    
    add_custom_command(OUTPUT ${NANOPB_SRCS}
            COMMAND ${PROTO_COMPILER} 
                -I ${PROTO_BASE_DIR}
                --nanopb_out=${NANOPB_OUT_PATH} 
                ${PROTO_SRCS}
            WORKING_DIRECTORY ${PROTO_BASE_DIR}
            DEPENDS ${PROTO_SRCS}
            COMMENT "Generating nanopb C code from protocol buffers"
            VERBATIM)
endif()

if(ESP_PLATFORM)
idf_component_register(SRCS "${NANOPB_SRCS}" INCLUDE_DIRS "${CMAKE_CURRENT_LIST_DIR}/nanopb")
else()
add_library(protobufs STATIC ${NANOPB_SRCS})
target_include_directories(protobufs PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}/nanopb
)
target_compile_definitions(protobufs PUBLIC PB_BUFFER_ONLY)
target_compile_definitions(protobufs PUBLIC PB_LITTLE_ENDIAN_8BIT)
target_compile_definitions(protobufs PUBLIC PB_NO_ERRMSG)
target_sources(protobufs PRIVATE ${NANOPB_SRCS})
endif()

