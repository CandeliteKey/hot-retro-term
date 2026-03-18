# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**cool-retro-term** is a Qt 6 terminal emulator that mimics CRT screen aesthetics using GLSL shaders. It's split into a main application and a terminal widget subproject.

## Build

**Dependencies**: Qt 6.10.0+ with `qt5compat` and `qtshadertools` modules, plus platform libs (OpenGL, Xlib on Linux; CoreFoundation on macOS).

```bash
# Build
qmake && make

# Run
./cool-retro-term

# Build distributable (Linux)
./scripts/build-appimage.sh
```

**Note**: Shader `.qsb` files are pre-compiled binaries (via Qt Shader Baker). Modifying `.frag` shaders requires recompiling them with `qsb`.

## Architecture

The codebase splits cleanly into three layers:

### C++ Backend (`app/`)
- **main.cpp**: Initializes QApplication/QQmlApplicationEngine, handles CLI args, registers C++ types with QML, enforces single-instance via `KDSingleApplication` submodule.
- **fontmanager.cpp**: Enumerates system monospace fonts + bundled retro fonts. Exposes font metrics (scaling, width, line spacing) as QML-bindable properties. Emits `terminalFontChanged` on changes.
- **fileio.cpp**: Thin file read/write wrapper exposed to QML for settings file operations.

### QML UI (`app/qml/`)
- **main.qml**: Root QtObject managing application state, windows, and global settings.
- **ApplicationSettings.qml**: Central settings store — all visual effects (curvature, bloom, burn-in, chroma, flicker, jitter, noise), colors, and font properties live here as bindable properties.
- **Storage.qml**: Persists settings to SQLite via Qt LocalStorage (`settings` table with key/value pairs).
- **TerminalWindow.qml**: ApplicationWindow with menu bar, keyboard shortcuts (Alt+1-9 for tabs, Ctrl+Shift+T new tab, Ctrl+Shift+W close tab, Ctrl+/- zoom), and tab management.
- **TerminalTabs.qml**: Tab bar managing multiple terminal sessions per window.
- **PreprocessedTerminal.qml → TerminalContainer.qml → QMLTermWidget**: The rendering chain from layout container to the C++ terminal emulation plugin.
- **ShaderTerminal.qml**: Applies CRT visual effects via ShaderEffectSource pipeline.

### Terminal Widget Subproject (`qmltermwidget/`)
A QML plugin wrapping a Konsole-derived terminal emulator. Key components: `Session` (manages PTY), `Emulation` (VT102 protocol), `Screen` (buffer), `Pty` (pseudo-terminal). Exposed to QML as a plugin via `qmltermwidget_plugin.cpp`.

## Shader System

`app/shaders/` contains two main fragment shaders with many precompiled variants:
- **terminal_dynamic.frag**: Animated effects — rasterization modes (0–4), burn-in, frame display, chroma aberration → ~40 variants
- **terminal_static.frag**: Static effects — RGB shift, bloom, curvature, frame shininess → 16 variants
- **terminal_frame.frag/vert**: Decorative bezel rendering

Variants are selected at runtime based on `ApplicationSettings` property values.

## CLI Flags

```
--default-settings     Reset to defaults
--workdir <dir>        Set working directory (defaults to current directory)
-e <cmd>               Execute command
-p|--profile <name>    Load saved profile
--fullscreen           Start fullscreen
--verbose              Debug output
```
