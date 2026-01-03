// game.zig
const std = @import("std");
const c = @import("c.zig").c;
const RenderTarget = @import("render_target.zig").RenderTarget;
const Renderer = @import("renderer.zig").Renderer;
const Shader = @import("shader.zig").Shader;
const Mesh = @import("mesh.zig").Mesh;
const Camera = @import("camera.zig").Camera;
const torus_module = @import("torus.zig");
const math = @import("math.zig");

const Vec2 = math.Vec2;

const FIXED_TIMESTEP: f32 = 1.0 / 12000.0;
const MAX_ACCUMULATED_TIME: f32 = FIXED_TIMESTEP * 5.0;

pub const Game = struct {
    allocator: std.mem.Allocator,

    // gol state
    gol_targets: [2]RenderTarget,
    current_target: usize,
    texel_size: [2]f32,
    accumulator: f32,

    // scene
    torus: Mesh,
    rotation: f32,
    camera: Camera,

    // shaders (game owns these since they're game-specific)
    basic_shader: Shader,
    gol_shader: Shader,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, aspect_ratio: f32) !Self {
        const torus_data = try torus_module.createTorus(allocator, 512, 2.0, 1);
        defer allocator.free(torus_data.vertices);
        defer allocator.free(torus_data.indices);

        const gol_targets = [2]RenderTarget{
            RenderTarget.init(torus_data.grid_width, torus_data.grid_height, .r8, false),
            RenderTarget.init(torus_data.grid_width, torus_data.grid_height, .r8, false),
        };

        const texel_size = [2]f32{
            1.0 / @as(f32, @floatFromInt(torus_data.grid_width)),
            1.0 / @as(f32, @floatFromInt(torus_data.grid_height)),
        };

        var self = Self{
            .allocator = allocator,
            .gol_targets = gol_targets,
            .current_target = 0,
            .texel_size = texel_size,
            .accumulator = 0,
            .torus = Mesh.init(torus_data.vertices, torus_data.indices),
            .rotation = 0,
            .camera = Camera.init(aspect_ratio),
            .basic_shader = try Shader.init(allocator, "basic", "shaders/basic.vert", "shaders/basic.frag"),
            .gol_shader = try Shader.init(allocator, "gol", "shaders/blit.vert", "shaders/gol.frag"),
        };

        try self.randomizeGrid(&self.gol_targets[0]);

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.gol_targets[0].deinit();
        self.gol_targets[1].deinit();
        self.torus.deinit();
        self.basic_shader.deinit();
        self.gol_shader.deinit();
    }

    pub fn reset(self: *Self) !void {
        try self.randomizeGrid(&self.gol_targets[0]);
        try self.randomizeGrid(&self.gol_targets[1]);
        self.current_target = 0;
    }

    pub fn update(self: *Self, delta: f32, renderer: *Renderer, move_dir: Vec2, zoom: f32) void {
        self.camera.updateOrbit(move_dir, zoom, delta);

        // gol simulation (fixed timestep)
        self.accumulator += delta;
        if (self.accumulator > MAX_ACCUMULATED_TIME) {
            self.accumulator = MAX_ACCUMULATED_TIME;
        }

        while (self.accumulator >= FIXED_TIMESTEP) {
            self.stepSimulation(renderer);
            self.accumulator -= FIXED_TIMESTEP;
        }
    }

    fn stepSimulation(self: *Self, renderer: *Renderer) void {
        const src = &self.gol_targets[self.current_target];
        const dst = &self.gol_targets[1 - self.current_target];

        dst.clear(null);
        renderer.setDepthTest(false);
        renderer.setCulling(.none);

        self.gol_shader.use();
        self.gol_shader.setInt("uGrid", 0);
        self.gol_shader.setVec2("uTexelSize", &self.texel_size);
        src.bindTexture(0);
        renderer.drawFullscreenQuad();

        self.current_target = 1 - self.current_target;
    }

    pub fn render(self: *Self, renderer: *Renderer, target: *const RenderTarget) void {
        target.clear(.{ 0.1, 0.1, 0.1, 1.0 });
        renderer.setDepthTest(true);
        renderer.setCulling(.back);

        const model = math.Mat4.translate(0, 0, 0)
            .multiply(math.Quat.fromAxisAngle(.{ .x = 1, .y = 0, .z = 1 }, self.rotation).toMat4());
        const view = self.camera.getViewMatrix();
        const projection = self.camera.getProjectionMatrix();

        self.basic_shader.use();
        self.basic_shader.setMat4("uModel", &model.data);
        self.basic_shader.setMat4("uView", &view.data);
        self.basic_shader.setMat4("uProjection", &projection.data);
        self.basic_shader.setInt("uGrid", 0);

        self.gol_targets[self.current_target].bindTexture(0);
        self.torus.draw();
    }

    fn randomizeGrid(self: *Self, target: *RenderTarget) !void {
        var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        const random = prng.random();

        const pixels = try self.allocator.alloc(u8, target.width * target.height);
        defer self.allocator.free(pixels);

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
};
