
if(NOT GAS)
    message(FATAL_ERROR "${IMPL} requires GNU assembler")
endif()

add_library(tico STATIC
    switch.s
)
