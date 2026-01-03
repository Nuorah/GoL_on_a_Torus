// debug_ui.zig
const std = @import("std");
const c = @import("c.zig").c;

pub const DebugUI = struct {
    // any state you need later goes here
    show_stats: bool = true,

    const Self = @This();

    pub fn init(window_handle: *anyopaque) Self {
        _ = c.ImGui_CreateContext(null);
        const io = c.ImGui_GetIO();
        _ = c.ImFontAtlas_AddFontFromFileTTF(
            io.*.Fonts,
            "libs/fonts/ProggyClean.ttf",
            30.0,
            null,
            null,
        );
        _ = c.cImGui_ImplGlfw_InitForOpenGL(@ptrCast(window_handle), true);
        _ = c.cImGui_ImplOpenGL3_Init();
        return Self{};
    }

    pub fn deinit(self: *Self) void {
        _ = self;
        c.cImGui_ImplOpenGL3_Shutdown();
        c.cImGui_ImplGlfw_Shutdown();
        c.ImGui_DestroyContext(null);
    }

    pub fn beginFrame(self: *Self) void {
        _ = self;
        c.cImGui_ImplOpenGL3_NewFrame();
        c.cImGui_ImplGlfw_NewFrame();
        c.ImGui_NewFrame();
    }

    pub fn endFrame(self: *Self) void {
        _ = self;
        c.ImGui_Render();
        c.cImGui_ImplOpenGL3_RenderDrawData(c.ImGui_GetDrawData());
    }

    pub fn showStats(self: *Self, fps: f32, delta: f32) void {
        if (!self.show_stats) return;
        if (c.ImGui_Begin("Stats", &self.show_stats, 0)) {
            var buf: [64]u8 = undefined;
            const fps_str = std.fmt.bufPrintZ(&buf, "FPS: {d:.1}", .{fps}) catch "FPS: ???";
            c.ImGui_Text("%s", fps_str.ptr);
            const dt_str = std.fmt.bufPrintZ(&buf, "dt: {d:.2}ms", .{delta * 1000.0}) catch "dt: ???";
            c.ImGui_Text("%s", dt_str.ptr);
        }
        c.ImGui_End();
    }
};
