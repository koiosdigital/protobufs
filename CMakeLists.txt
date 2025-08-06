cmake_minimum_required(VERSION 3.15)
    
set(PROTO_COMPILER "protoc")
set(NANOPB_OUT_PATH "${CMAKE_CURRENT_LIST_DIR}/nanopb")

set(NANOPB_SRCS
    "${NANOPB_OUT_PATH}/levitree.pb.c"
    "${NANOPB_OUT_PATH}/device_adc.pb.c"
    "${NANOPB_OUT_PATH}/device_efc.pb.c"
    "${NANOPB_OUT_PATH}/device_vfd.pb.c"
    "${NANOPB_OUT_PATH}/device_rover.pb.c"
    "${NANOPB_OUT_PATH}/discovery.pb.c"
    "${NANOPB_OUT_PATH}/heartbeat.pb.c"
    "${NANOPB_OUT_PATH}/enums.pb.c"
    "${NANOPB_OUT_PATH}/pb_common.c"
    "${NANOPB_OUT_PATH}/pb_encode.c"
    "${NANOPB_OUT_PATH}/pb_decode.c"
)

set(PROTO_SRCS
    "${CMAKE_CURRENT_LIST_DIR}/proto/levitree.proto"
    "${CMAKE_CURRENT_LIST_DIR}/proto/device_adc.proto"
    "${CMAKE_CURRENT_LIST_DIR}/proto/device_efc.proto"
    "${CMAKE_CURRENT_LIST_DIR}/proto/device_vfd.proto"
    "${CMAKE_CURRENT_LIST_DIR}/proto/device_rover.proto"
    "${CMAKE_CURRENT_LIST_DIR}/proto/discovery.proto"
    "${CMAKE_CURRENT_LIST_DIR}/proto/heartbeat.proto"
    "${CMAKE_CURRENT_LIST_DIR}/proto/enums.proto"
)

if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    file(MAKE_DIRECTORY ${NANOPB_OUT_PATH})
    add_custom_command(OUTPUT ${NANOPB_SRCS}
            COMMAND ${PROTO_COMPILER} -I ${CMAKE_CURRENT_LIST_DIR}/proto --nanopb_out=${NANOPB_OUT_PATH} ${PROTO_SRCS}
            WORKING_DIRECTORY ${CMAKE_CURRENT_LIST_DIR}/proto
            DEPENDS ${PROTO_SRCS}
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

