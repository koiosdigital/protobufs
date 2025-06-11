cmake_minimum_required(VERSION 3.15)
    
set(PROTO_COMPILER "protoc")
set(PROTO_C_COMPILER "protoc")
set(C_OUT_PATH "${CMAKE_CURRENT_LIST_DIR}/proto-c")
set(NANOC_OUT_PATH "${CMAKE_CURRENT_LIST_DIR}/nanopb")
    
set(PROTO_SRCS 
    "${CMAKE_CURRENT_LIST_DIR}/levitree.proto"
    "${CMAKE_CURRENT_LIST_DIR}/device_adc.proto"
    "${CMAKE_CURRENT_LIST_DIR}/device_vfd.proto"
    "${CMAKE_CURRENT_LIST_DIR}/discovery.proto"
    "${CMAKE_CURRENT_LIST_DIR}/heartbeat.proto"
    "${CMAKE_CURRENT_LIST_DIR}/enums.proto"
)
    
set(pb_csrcs
    "${C_OUT_PATH}/levitree.pb-c.c"
    "${C_OUT_PATH}/device_adc.pb-c.c"
    "${C_OUT_PATH}/device_vfd.pb-c.c"
    "${C_OUT_PATH}/discovery.pb-c.c"
    "${C_OUT_PATH}/heartbeat.pb-c.c"
    "${C_OUT_PATH}/enums.pb-c.c"
)

set(npb_csrcs
    "${NANOC_OUT_PATH}/levitree.pb.c"
    "${NANOC_OUT_PATH}/device_adc.pb.c"
    "${NANOC_OUT_PATH}/device_vfd.pb.c"
    "${NANOC_OUT_PATH}/discovery.pb.c"
    "${NANOC_OUT_PATH}/heartbeat.pb.c"
    "${NANOC_OUT_PATH}/enums.pb.c"
)
    
if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    add_custom_command(OUTPUT ${pb_csrcs}
            COMMAND ${PROTO_C_COMPILER} --nanopb_out=${NANOC_OUT_PATH} ./*.proto
            DEPENDS ${PROTO_SRCS}
            VERBATIM)
endif()

if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    add_custom_command(OUTPUT ${npb_csrcs}
            COMMAND ${PROTO_C_COMPILER} -I ${CMAKE_CURRENT_LIST_DIR} --c_out=${C_OUT_PATH} ${PROTO_SRCS}
            DEPENDS ${PROTO_SRCS}
            VERBATIM)
endif()

set(inc_dirs 
    "${CMAKE_CURRENT_LIST_DIR}/proto-c"
    "${CMAKE_CURRENT_LIST_DIR}/nanopb"
)

set(srcs
    "${pb_csrcs}"
    "${npb_csrcs}"
)
    
idf_component_register(SRCS "${srcs}" INCLUDE_DIRS "${inc_dirs}" REQUIRES protobuf-c)