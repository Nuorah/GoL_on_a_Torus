const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glfw = buildGLFW(b, target, optimize);
    const imgui = buildImGui(b, target, optimize);

    const exe = b.addExecutable(.{
        .name = "conway_game_of_torus",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // glad
    exe.addCSourceFile(.{
        .file = b.path("libs/glad/glad.c"),
        .flags = &.{},
    });

    // stb implementations
    exe.addCSourceFile(.{
        .file = b.path("libs/stb/stb_impl.c"),
        .flags = &.{},
    });

    exe.addIncludePath(b.path("libs/glad"));
    exe.addIncludePath(b.path("libs/KHR"));
    exe.addIncludePath(b.path("libs/glfw/include"));
    exe.addIncludePath(b.path("libs/imgui"));
    exe.addIncludePath(b.path("libs/stb"));
    exe.addIncludePath(b.path("libs"));

    exe.linkLibrary(glfw);
    exe.linkLibrary(imgui);
    exe.linkLibC();
    exe.linkLibCpp();

    switch (target.result.os.tag) {
        .linux => {
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("X11");
            exe.linkSystemLibrary("m");
        },
        .windows => {
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("opengl32");
        },
        else => @panic("ngmi: unsupported platform"),
    }

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}

fn buildImGui(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const imgui = b.addLibrary(.{
        .linkage = .static,
        .name = "imgui",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = optimize,
        }),
    });

    imgui.addIncludePath(b.path("libs/imgui"));
    imgui.addIncludePath(b.path("libs/glfw/include"));
    imgui.addIncludePath(b.path("libs/glad"));
    imgui.linkLibCpp();

    imgui.addCSourceFiles(.{
        .files = &.{
            "libs/imgui/imgui.cpp",
            "libs/imgui/imgui_demo.cpp",
            "libs/imgui/imgui_draw.cpp",
            "libs/imgui/imgui_tables.cpp",
            "libs/imgui/imgui_widgets.cpp",
            "libs/imgui/imgui_impl_glfw.cpp",
            "libs/imgui/imgui_impl_opengl3.cpp",
            "libs/imgui/dcimgui.cpp",
            "libs/imgui/dcimgui_impl_glfw.cpp",
            "libs/imgui/dcimgui_impl_opengl3.cpp",
        },
    });

    return imgui;
}

fn buildGLFW(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const glfw = b.addLibrary(.{
        .linkage = .static,
        .name = "glfw",
        .root_module = b.createModule(.{
            .root_source_file = null,
            .target = target,
            .optimize = optimize,
        }),
    });

    const core_sources = [_][]const u8{
        "context.c",
        "init.c",
        "input.c",
        "vulkan.c",
        "monitor.c",
        "window.c",
        "egl_context.c",
        "osmesa_context.c",
        "platform.c",
        "null_init.c",
        "null_monitor.c",
        "null_window.c",
        "null_joystick.c",
    };

    for (core_sources) |src| {
        glfw.addCSourceFile(.{
            .file = b.path(b.fmt("libs/glfw/src/{s}", .{src})),
            .flags = getGLFWFlags(target),
        });
    }

    switch (target.result.os.tag) {
        .linux => {
            const linux_sources = [_][]const u8{
                "x11_init.c",
                "x11_monitor.c",
                "x11_window.c",
                "glx_context.c",
                "posix_time.c",
                "posix_thread.c",
                "posix_module.c",
                "posix_poll.c",
                "linux_joystick.c",
                "xkb_unicode.c",
            };
            for (linux_sources) |src| {
                glfw.addCSourceFile(.{
                    .file = b.path(b.fmt("libs/glfw/src/{s}", .{src})),
                    .flags = getGLFWFlags(target),
                });
            }
        },
        .windows => {
            const win_sources = [_][]const u8{
                "win32_init.c",
                "win32_joystick.c",
                "win32_monitor.c",
                "win32_time.c",
                "win32_thread.c",
                "win32_window.c",
                "win32_module.c",
                "wgl_context.c",
            };
            for (win_sources) |src| {
                glfw.addCSourceFile(.{
                    .file = b.path(b.fmt("libs/glfw/src/{s}", .{src})),
                    .flags = getGLFWFlags(target),
                });
            }
        },
        else => @panic("ngmi: unsupported platform"),
    }

    glfw.addIncludePath(b.path("libs/glfw/include"));
    glfw.addIncludePath(b.path("libs/glfw/src"));
    glfw.linkLibC();

    return glfw;
}

fn getGLFWFlags(target: std.Build.ResolvedTarget) []const []const u8 {
    return switch (target.result.os.tag) {
        .linux => &.{"-D_GLFW_X11"},
        .windows => &.{"-D_GLFW_WIN32"},
        else => &.{},
    };
}
