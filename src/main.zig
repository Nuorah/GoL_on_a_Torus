// main.zig
const std = @import("std");
const c = @import("c.zig").c;
const Window = @import("window.zig").Window;
const Input = @import("input.zig").Input;
const ActionMap = @import("action.zig").ActionMap;
const Renderer = @import("renderer.zig").Renderer;
const RenderTarget = @import("render_target.zig").RenderTarget;
const Shader = @import("shader.zig").Shader;
const Game = @import("game.zig").Game;
const DebugUI = @import("debug_ui.zig").DebugUI;

const WINDOW_WIDTH: u32 = 1920;
const WINDOW_HEIGHT: u32 = 1080;
const RENDER_WIDTH: f32 = 1920;
const RENDER_HEIGHT: f32 = 1080;

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    // Init window
    var win = try Window.init(WINDOW_WIDTH, WINDOW_HEIGHT, "GoL on a torus");
    defer win.deinit();
    win.setupCallbacks();

    if (c.gladLoadGL() == 0) {
        std.debug.print("failed to load GL\n", .{});
        return error.GLLoadFailed;
    }

    // Init input
    var input = Input.init();
    const actions = ActionMap.init();

    // Init debug ui
    var debug_ui = DebugUI.init(win.handle);
    defer debug_ui.deinit();

    // Init renderer
    var renderer = Renderer.init();
    defer renderer.deinit();

    // Target on which we render the whole thing, and its shader
    const screen_target = RenderTarget.init(@intFromFloat(RENDER_WIDTH), @intFromFloat(RENDER_HEIGHT), .rgb, true);
    defer screen_target.deinit();

    const blit_shader = try Shader.init(allocator, "blit", "shaders/blit.vert", "shaders/blit.frag");
    defer blit_shader.deinit();

    // Init game logic
    var game = try Game.init(allocator, RENDER_WIDTH / RENDER_HEIGHT, 1.0, 512, 2, 1);
    defer game.deinit();

    var last_time: i64 = std.time.milliTimestamp();

    var fps: f32 = 0;
    var frame_count: u32 = 0;
    var fps_timer: f32 = 0;

    while (!win.shouldClose()) {
        const current_time = std.time.milliTimestamp();
        const delta: f32 = @as(f32, @floatFromInt(current_time - last_time)) / 1000.0;
        last_time = current_time;

        frame_count += 1;
        fps_timer += delta;
        if (fps_timer >= 1.0) {
            fps = @as(f32, @floatFromInt(frame_count)) / fps_timer;
            frame_count = 0;
            fps_timer = 0;
        }

        // INPUT
        input.newFrame();
        while (true) {
            switch (win.pollEvent()) {
                .none => break,
                .quit => return,
                .input => |e| input.handleEvent(e),
            }
        }

        if (actions.isPressed(input, .toggle_fullscreen)) {
            win.toggleFullscreen();
            c.glFinish();
        }
        if (actions.isPressed(input, .toggle_vsync)) {
            std.debug.print("toggle vsync\n", .{});
            win.toggleVsync();
            c.glFinish();
        }

        if (actions.isPressed(input, .quit)) return;
        if (actions.isPressed(input, .reset)) try game.reset();

        var move_dir = actions.getMoveDir(input);

        if (input.isMouseButtonHeld(.left) and !debug_ui.wantsCaptureMouse()) {
            const sensitivity: f32 = 0.05;
            move_dir.x -= @as(f32, @floatFromInt(input.mouse_dx)) * sensitivity;
            move_dir.y += @as(f32, @floatFromInt(input.mouse_dy)) * sensitivity;
        }

        var zoom: f32 = 0;
        if (actions.isHeld(input, .zoom_in)) zoom += 1;
        if (actions.isHeld(input, .zoom_out)) zoom -= 1;
        zoom += input.scroll_dy * 5;

        // GAME UPDATE
        game.update(delta, &renderer, move_dir, zoom);
        // GAME RENDER
        game.render(&renderer, &screen_target);

        renderer.bindDefaultFramebuffer();
        renderer.clearScreen(0.0, 0.0, 0.0);
        win.syncDimensions();
        const vp = Renderer.calculateViewport(win.width, win.height, RENDER_WIDTH, RENDER_HEIGHT);
        renderer.setViewport(vp.x, vp.y, vp.w, vp.h);
        renderer.setDepthTest(false);
        renderer.setCulling(.none);
        blit_shader.use();
        blit_shader.setInt("uScreen", 0);
        screen_target.bindTexture(0);
        renderer.drawFullscreenQuad();

        debug_ui.beginFrame();
        debug_ui.showStats(fps, delta);
        debug_ui.parameters(&game);
        debug_ui.regenerate(&game);
        debug_ui.endFrame();

        win.swapBuffers();
    }
}
