cmake_minimum_required(VERSION 3.19)

project(cool-retro-term
    VERSION 0.1
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.10 REQUIRED COMPONENTS
    Core Qml Quick Widgets Sql QuickControls2 ShaderTools
)

# KDSingleApplication: static submodule build
set(KDSingleApplication_STATIC   ON  CACHE BOOL "" FORCE)
set(KDSingleApplication_TESTS    OFF CACHE BOOL "" FORCE)
set(KDSingleApplication_EXAMPLES OFF CACHE BOOL "" FORCE)
set(KDSingleApplication_DOCS     OFF CACHE BOOL "" FORCE)
add_subdirectory(KDSingleApplication)

add_subdirectory(qmltermwidget)
add_subdirectory(app)
