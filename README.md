# Torus GoL

Game of Life simulation running on a torus surface. Zig + OpenGL.

## What it does

Conway's Game of Life, but the grid is rendered around a 3D torus instead of a flat plane. GPU simulation via ping-pong framebuffers.

## Prerequisites

- Zig 0.15.x
- OpenGL 3.3+ capable GPU
- GLFW, glad, dear imgui (vendored in libs/)

## Build & Run

```bash
zig build run
```

## Controls

- WASD / mouse drag - orbit camera
- Q/E / scroll - zoom
- R - randomize grid
- F11 - fullscreen
- V - toggle vsync
- Escape - quit

## Why?

Why not?
