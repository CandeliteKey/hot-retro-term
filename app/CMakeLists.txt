cmake_minimum_required(VERSION 3.19)

find_package(Qt6 REQUIRED COMPONENTS
    Core Qml Quick Widgets Sql QuickControls2 ShaderTools
)

# --- App version from git ---
execute_process(
    COMMAND git -C ${CMAKE_CURRENT_SOURCE_DIR}/.. describe --tags --always --dirty=-dirty
    OUTPUT_VARIABLE APP_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(NOT APP_VERSION)
    set(APP_VERSION "unknown")
endif()

# --- Executable ---
qt_add_executable(cool-retro-term
    main.cpp
    fileio.cpp
    fontmanager.cpp
    fontlistmodel.cpp
    curvatureinputfilter.cpp
    fileio.h
    fontmanager.h
    fontlistmodel.h
    curvatureinputfilter.h
    qml/resources.qrc
)

target_compile_definitions(cool-retro-term PRIVATE
    APP_VERSION="${APP_VERSION}"
)

target_include_directories(cool-retro-term PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/KDSingleApplication/src
)

target_link_libraries(cool-retro-term PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Quick
    Qt6::Widgets
    Qt6::Sql
    Qt6::QuickControls2
    KDAB::kdsingleapplication
)

if(APPLE)
    set_target_properties(cool-retro-term PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_ICON_FILE crt.icns
    )
    target_sources(cool-retro-term PRIVATE icons/crt.icns)
    set_source_files_properties(icons/crt.icns PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources"
    )
    target_link_libraries(cool-retro-term PRIVATE "-framework CoreFoundation")
endif()

# QMLTermWidget is loaded at runtime via QML import path, not linked.
# Declare explicit dependency so CLion/cmake --build always builds the plugin first.
add_dependencies(cool-retro-term qmltermwidget)

# Place the binary at the build root (mirrors qmake DESTDIR = $$OUT_PWD/../)
set_target_properties(cool-retro-term PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

# --- Shader compilation ---
# .qsb files are pre-compiled and committed to the source tree.
# The compile_shaders target regenerates them when source .frag/.vert files change.
# Normal builds use the existing .qsb files via the QRC; run this target after editing shaders.

find_program(QSB_EXECUTABLE qsb
    HINTS
        "${Qt6_DIR}/../../../libexec"
        "${Qt6_DIR}/../../../bin"
)

if(QSB_EXECUTABLE)
    set(SHADERS_DIR ${CMAKE_CURRENT_SOURCE_DIR}/shaders)
    set(QSB_FLAGS --glsl "100 es,120,150" --hlsl 50 --msl 12 --qt6)
    set(ALL_SHADER_OUTPUTS)

    # Direct shaders (non-variant)
    foreach(SHADER
        burn_in.frag
        burn_in.vert
        terminal_dynamic.vert
        terminal_frame.frag
        terminal_frame.vert
        terminal_static.vert
        window_curvature.frag
        window_curvature.vert
    )
        set(INPUT  ${SHADERS_DIR}/${SHADER})
        set(OUTPUT ${SHADERS_DIR}/${SHADER}.qsb)
        add_custom_command(
            OUTPUT  ${OUTPUT}
            COMMAND ${QSB_EXECUTABLE} ${QSB_FLAGS} -o ${OUTPUT} ${INPUT}
            DEPENDS ${INPUT}
            COMMENT "qsb: ${SHADER}"
        )
        list(APPEND ALL_SHADER_OUTPUTS ${OUTPUT})
    endforeach()

    # Dynamic shader variants: terminal_dynamic.frag
    # raster: 0-4, burn_in: 0-1, display_frame: 0-1, chroma: 0-1  (40 variants)
    set(DYNAMIC_SRC ${SHADERS_DIR}/terminal_dynamic.frag)
    foreach(RASTER 0 1 2 3 4)
        foreach(BURN 0 1)
            foreach(FRAME 0 1)
                foreach(CHROMA 0 1)
                    set(NAME "terminal_dynamic_raster${RASTER}_burn${BURN}_frame${FRAME}_chroma${CHROMA}")
                    set(OUTPUT ${SHADERS_DIR}/${NAME}.frag.qsb)
                    add_custom_command(
                        OUTPUT  ${OUTPUT}
                        COMMAND ${QSB_EXECUTABLE} ${QSB_FLAGS}
                            -DCRT_RASTER_MODE=${RASTER}
                            -DCRT_BURN_IN=${BURN}
                            -DCRT_DISPLAY_FRAME=${FRAME}
                            -DCRT_CHROMA=${CHROMA}
                            -o ${OUTPUT} ${DYNAMIC_SRC}
                        DEPENDS ${DYNAMIC_SRC}
                        COMMENT "qsb: ${NAME}"
                    )
                    list(APPEND ALL_SHADER_OUTPUTS ${OUTPUT})
                endforeach()
            endforeach()
        endforeach()
    endforeach()

    # Static shader variants: terminal_static.frag
    # rgb_shift: 0-1, bloom: 0-1, curvature: 0-1, shininess: 0-1  (16 variants)
    set(STATIC_SRC ${SHADERS_DIR}/terminal_static.frag)
    foreach(RGB 0 1)
        foreach(BLOOM 0 1)
            foreach(CURVE 0 1)
                foreach(SHINE 0 1)
                    set(NAME "terminal_static_rgb${RGB}_bloom${BLOOM}_curve${CURVE}_shine${SHINE}")
                    set(OUTPUT ${SHADERS_DIR}/${NAME}.frag.qsb)
                    add_custom_command(
                        OUTPUT  ${OUTPUT}
                        COMMAND ${QSB_EXECUTABLE} ${QSB_FLAGS}
                            -DCRT_RGB_SHIFT=${RGB}
                            -DCRT_BLOOM=${BLOOM}
                            -DCRT_CURVATURE=${CURVE}
                            -DCRT_FRAME_SHININESS=${SHINE}
                            -o ${OUTPUT} ${STATIC_SRC}
                        DEPENDS ${STATIC_SRC}
                        COMMENT "qsb: ${NAME}"
                    )
                    list(APPEND ALL_SHADER_OUTPUTS ${OUTPUT})
                endforeach()
            endforeach()
        endforeach()
    endforeach()

    add_custom_target(compile_shaders DEPENDS ${ALL_SHADER_OUTPUTS})
else()
    message(STATUS "qsb not found — using pre-compiled .qsb files. Run 'cmake --build . --target compile_shaders' after installing Qt ShaderTools.")
    add_custom_target(compile_shaders
        COMMAND ${CMAKE_COMMAND} -E echo "qsb not found; cannot compile shaders."
    )
endif()

# --- Install ---
include(GNUInstallDirs)

install(TARGETS cool-retro-term
    BUNDLE  DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(UNIX AND NOT APPLE)
    install(FILES ${CMAKE_SOURCE_DIR}/cool-retro-term.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
    )
    foreach(SIZE 32 64 128 256)
        install(FILES icons/${SIZE}x${SIZE}/cool-retro-term.png
            DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/${SIZE}x${SIZE}/apps
        )
    endforeach()
endif()
