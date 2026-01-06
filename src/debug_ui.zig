const std = @import("std");
const c = @import("c.zig").c;
const Game = @import("game.zig").Game;

pub const DebugUI = struct {
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

    pub fn wantsCaptureMouse(_: *Self) bool {
        const io = c.ImGui_GetIO();
        return io.*.WantCaptureMouse;
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

    pub fn parameters(_: *Self, game: *Game) void {
        if (c.ImGui_Begin("Parameters", null, 0)) {
            c.ImGui_PushItemWidth(80);
            _ = c.ImGui_DragFloatEx("steps per second", &game.frequency, 1, 0, 60, "%.0f", 0);
            c.ImGui_PopItemWidth();
        }
        c.ImGui_End();
    }

    pub fn regenerate(_: *Self, game: *Game) void {
        if (c.ImGui_Begin("Regenerate", null, 0)) {
            c.ImGui_SetNextItemWidth(100);
            _ = c.ImGui_DragIntEx("seed", @ptrCast(&game.seed), 1, 64, 8192, "%d", 0);

            c.ImGui_SetNextItemWidth(100);
            _ = c.ImGui_DragIntEx("resolution", @ptrCast(&game.grid_resolution), 1, 64, 2048, "%d", 0);

            c.ImGui_SetNextItemWidth(100);
            _ = c.ImGui_DragFloatEx("major radius", &game.major_radius, 0.1, 0.5, 10.0, "%.1f", 0);

            c.ImGui_SetNextItemWidth(100);
            _ = c.ImGui_DragFloatEx("minor radius", &game.minor_radius, 0.1, 0.1, 5.0, "%.1f", 0);

            c.ImGui_SetNextItemWidth(100);
            _ = c.ImGui_DragFloatEx("fill %", &game.density, 0.01, 0.0, 1.0, "%.2f", 0);

            if (c.ImGui_Button("Regenerate")) {
                game.regenerate() catch {};
            }
        }
        c.ImGui_End();
    }
};
