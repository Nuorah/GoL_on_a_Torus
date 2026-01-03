const std = @import("std");
const c = @import("c.zig").c;
const shader_module = @import("shader.zig");
const math = @import("math.zig");
const Mesh = @import("mesh.zig").Mesh;
const Vertex = @import("vertex.zig").Vertex;
const Camera = @import("camera.zig").Camera;
const RenderTarget = @import("render_target.zig").RenderTarget;
const Window = @import("window_glfw.zig").Window;
const Input = @import("input.zig").Input;
const ActionMap = @import("action.zig").ActionMap;

const WINDOW_WIDTH: u32 = 1920;
const WINDOW_HEIGHT: u32 = 1280;

const RENDER_WIDTH: f32 = 1920;
const RENDER_HEIGHT: f32 = 1280;

const FIXED_TIMESTEP: f32 = 1.0 / 10.0;
const MAX_ACCUMULATED_TIME: f32 = FIXED_TIMESTEP * 5.0;

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var win = try Window.init(WINDOW_WIDTH, WINDOW_HEIGHT, "hello zig");
    defer win.deinit();

    var input = Input.init();
    const actions = ActionMap.init();

    if (c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == 0) {
        std.debug.print("failed to load GL\n", .{});
        return error.GLLoadFailed;
    }

    std.debug.print("OpenGL loaded, we're so back\n", .{});

    const screen_target = RenderTarget.init(@intFromFloat(RENDER_WIDTH), @intFromFloat(RENDER_HEIGHT), .rgb, true);
    defer screen_target.deinit();

    const shader = try shader_module.Shader.init(allocator, "basic", "shaders/basic.vert", "shaders/basic.frag");
    defer shader.deinit();

    const blit_shader = try shader_module.Shader.init(allocator, "blit", "shaders/blit.vert", "shaders/blit.frag");
    defer blit_shader.deinit();

    const gol_shader = try shader_module.Shader.init(allocator, "gol", "shaders/blit.vert", "shaders/gol.frag");
    defer gol_shader.deinit();

    const torus_data = try createTorus(allocator, 128, 2.0, 1);
    defer allocator.free(torus_data.vertices);
    defer allocator.free(torus_data.indices);
    const torus = Mesh.init(torus_data.vertices, torus_data.indices);
    defer torus.deinit();

    var gol_targets = [2]RenderTarget{
        RenderTarget.init(torus_data.grid_width, torus_data.grid_height, .r8, false),
        RenderTarget.init(torus_data.grid_width, torus_data.grid_height, .r8, false),
    };
    defer gol_targets[0].deinit();
    defer gol_targets[1].deinit();
    var current_target: usize = 0;

    try initRandomGrid(allocator, &gol_targets[0]);

    const texel_size = [2]f32{
        1.0 / @as(f32, @floatFromInt(torus_data.grid_width)),
        1.0 / @as(f32, @floatFromInt(torus_data.grid_height)),
    };

    const fullscreen_quad_data = createFullscreenQuad();
    const fullscreen_quad = Mesh.init(&fullscreen_quad_data.vertices, &fullscreen_quad_data.indices);
    defer fullscreen_quad.deinit();

    c.glEnable(c.GL_DEPTH_TEST);
    c.glDepthFunc(c.GL_LESS);
    c.glEnable(c.GL_CULL_FACE);
    c.glCullFace(c.GL_BACK);
    c.glFrontFace(c.GL_CCW);

    const camera = Camera.init(RENDER_WIDTH / RENDER_HEIGHT);
    var rotation: f32 = 0;

    var accumulator: f32 = 0.0;
    var last_time: i64 = std.time.milliTimestamp();

    while (!win.shouldClose()) {
        const current_time = std.time.milliTimestamp();
        const delta_ms = current_time - last_time;
        last_time = current_time;
        const delta: f32 = @as(f32, @floatFromInt(delta_ms)) / 1000.0;

        rotation += 0.5 * delta;

        input.newFrame();

        while (true) {
            switch (win.pollEvent()) {
                .none => break,
                .quit => return,
                .resize => {},
                .input => |e| input.handleEvent(e),
            }
        }

        if (actions.isPressed(input, .toggle_fullscreen)) {
            win.toggleFullscreen();
            c.glFinish();
        }

        if (actions.isPressed(input, .quit)) return;

        if (actions.isPressed(input, .reset)) {
            try initRandomGrid(allocator, &gol_targets[0]);
            try initRandomGrid(allocator, &gol_targets[1]);
            current_target = 0;
        }

        accumulator += delta;
        if (accumulator > MAX_ACCUMULATED_TIME) {
            accumulator = MAX_ACCUMULATED_TIME;
        }

        while (accumulator >= FIXED_TIMESTEP) {
            const src = &gol_targets[current_target];
            const dst = &gol_targets[1 - current_target];

            dst.bind();
            c.glDisable(c.GL_DEPTH_TEST);
            c.glDisable(c.GL_CULL_FACE);
            gol_shader.use();
            gol_shader.setInt("uGrid", 0);
            gol_shader.setVec2("uTexelSize", &texel_size);
            src.bindTexture(0);
            fullscreen_quad.draw();
            c.glEnable(c.GL_DEPTH_TEST);
            c.glEnable(c.GL_CULL_FACE);

            current_target = 1 - current_target;
            accumulator -= FIXED_TIMESTEP;
        }

        screen_target.bind();
        c.glClearColor(0.1, 0.1, 0.1, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        const model = math.Mat4.translate(0, 0, 0)
            .multiply(math.Quat.fromAxisAngle(.{ .x = 1, .y = 0, .z = 1 }, rotation).toMat4());
        const view = camera.getViewMatrix();
        const projection = camera.getProjectionMatrix();

        shader.use();
        shader.setMat4("uModel", &model.data);
        shader.setMat4("uView", &view.data);
        shader.setMat4("uProjection", &projection.data);
        shader.setInt("uGrid", 0);

        gol_targets[current_target].bindTexture(0);
        torus.draw();

        RenderTarget.unbindFramebuffer();

        win.syncDimensions();
        c.glClearColor(0.0, 0.0, 0.0, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glDisable(c.GL_CULL_FACE);
        c.glDisable(c.GL_DEPTH_TEST);
        blit_shader.use();
        blit_shader.setInt("uScreen", 0);
        screen_target.bindTexture(0);
        fullscreen_quad.draw();
        c.glEnable(c.GL_CULL_FACE);
        c.glEnable(c.GL_DEPTH_TEST);

        win.swapBuffers();
    }

    std.debug.print("window closed, gmi\n", .{});
}

fn calculateViewport(window_w: u32, window_h: u32, render_w: f32, render_h: f32) struct { x: c.GLint, y: c.GLint, w: c.GLsizei, h: c.GLsizei } {
    const window_aspect = @as(f32, @floatFromInt(window_w)) / @as(f32, @floatFromInt(window_h));
    const render_aspect = render_w / render_h;

    var vp_w: f32 = undefined;
    var vp_h: f32 = undefined;

    if (window_aspect > render_aspect) {
        vp_h = @floatFromInt(window_h);
        vp_w = vp_h * render_aspect;
    } else {
        vp_w = @floatFromInt(window_w);
        vp_h = vp_w / render_aspect;
    }

    const vp_x = (@as(f32, @floatFromInt(window_w)) - vp_w) / 2.0;
    const vp_y = (@as(f32, @floatFromInt(window_h)) - vp_h) / 2.0;

    return .{
        .x = @intFromFloat(vp_x),
        .y = @intFromFloat(vp_y),
        .w = @intFromFloat(vp_w),
        .h = @intFromFloat(vp_h),
    };
}

fn initRandomGrid(allocator: std.mem.Allocator, target: *RenderTarget) !void {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();

    const pixels = try allocator.alloc(u8, target.width * target.height);
    defer allocator.free(pixels);

    for (pixels) |*pixel| {
        pixel.* = if (random.boolean()) 255 else 0;
    }

    c.glBindTexture(c.GL_TEXTURE_2D, target.texture);
    c.glTexSubImage2D(
        c.GL_TEXTURE_2D,
        0,
        0,
        0,
        @intCast(target.width),
        @intCast(target.height),
        c.GL_RED,
        c.GL_UNSIGNED_BYTE,
        pixels.ptr,
    );
    c.glBindTexture(c.GL_TEXTURE_2D, 0);
}

pub const Torus = struct {
    vertices: []Vertex,
    indices: []u32,
    grid_width: u32,
    grid_height: u32,
};

pub fn createTorus(
    allocator: std.mem.Allocator,
    cells_around_ring: u32,
    major_radius: f32,
    minor_radius: f32,
) !Torus {
    const ratio = major_radius / minor_radius;

    const grid_width = cells_around_ring;
    const grid_height: u32 = @intFromFloat(@round(@as(f32, @floatFromInt(cells_around_ring)) / ratio));

    const verts_w = grid_width + 1;
    const verts_h = grid_height + 1;
    const vertex_count = verts_w * verts_h;
    const index_count = grid_width * grid_height * 6;

    var vertices = try allocator.alloc(Vertex, vertex_count);
    var indices = try allocator.alloc(u32, index_count);

    for (0..verts_h) |j| {
        for (0..verts_w) |i| {
            const u = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(grid_width));
            const v = @as(f32, @floatFromInt(j)) / @as(f32, @floatFromInt(grid_height));

            const theta = v * std.math.pi * 2.0;
            const phi = u * std.math.pi * 2.0;

            const cos_theta = @cos(theta);
            const sin_theta = @sin(theta);
            const cos_phi = @cos(phi);
            const sin_phi = @sin(phi);

            const x = (major_radius + minor_radius * cos_theta) * cos_phi;
            const y = minor_radius * sin_theta;
            const z = (major_radius + minor_radius * cos_theta) * sin_phi;

            const nx = cos_theta * cos_phi;
            const ny = sin_theta;
            const nz = cos_theta * sin_phi;

            const tx = -sin_phi;
            const ty: f32 = 0;
            const tz = cos_phi;

            const idx = j * verts_w + i;
            vertices[idx] = .{
                .position = .{ x, y, z },
                .uv = .{ u, v },
                .normal = .{ nx, ny, nz },
                .tangent = .{ tx, ty, tz, 1.0 },
                .bone_ids = .{ 0, 0, 0, 0 },
                .bone_weights = .{ 1, 0, 0, 0 },
            };
        }
    }

    var idx: usize = 0;
    for (0..grid_height) |j| {
        for (0..grid_width) |i| {
            const tl: u32 = @intCast(j * verts_w + i);
            const tr: u32 = @intCast(j * verts_w + i + 1);
            const bl: u32 = @intCast((j + 1) * verts_w + i);
            const br: u32 = @intCast((j + 1) * verts_w + i + 1);

            indices[idx + 0] = tl;
            indices[idx + 1] = bl;
            indices[idx + 2] = tr;

            indices[idx + 3] = tr;
            indices[idx + 4] = bl;
            indices[idx + 5] = br;

            idx += 6;
        }
    }

    return .{
        .vertices = vertices,
        .indices = indices,
        .grid_width = grid_width,
        .grid_height = grid_height,
    };
}

pub fn createFullscreenQuad() struct { vertices: [4]Vertex, indices: [6]u32 } {
    const vertices = [4]Vertex{
        .{ .position = .{ -1, -1, 0 }, .uv = .{ 0, 0 }, .normal = .{ 0, 0, 1 }, .tangent = .{ 1, 0, 0, 1 }, .bone_ids = .{ 0, 0, 0, 0 }, .bone_weights = .{ 1, 0, 0, 0 } },
        .{ .position = .{ 1, -1, 0 }, .uv = .{ 1, 0 }, .normal = .{ 0, 0, 1 }, .tangent = .{ 1, 0, 0, 1 }, .bone_ids = .{ 0, 0, 0, 0 }, .bone_weights = .{ 1, 0, 0, 0 } },
        .{ .position = .{ 1, 1, 0 }, .uv = .{ 1, 1 }, .normal = .{ 0, 0, 1 }, .tangent = .{ 1, 0, 0, 1 }, .bone_ids = .{ 0, 0, 0, 0 }, .bone_weights = .{ 1, 0, 0, 0 } },
        .{ .position = .{ -1, 1, 0 }, .uv = .{ 0, 1 }, .normal = .{ 0, 0, 1 }, .tangent = .{ 1, 0, 0, 1 }, .bone_ids = .{ 0, 0, 0, 0 }, .bone_weights = .{ 1, 0, 0, 0 } },
    };

    const indices = [6]u32{ 0, 1, 2, 0, 2, 3 };

    return .{ .vertices = vertices, .indices = indices };
}
