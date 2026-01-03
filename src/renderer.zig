// renderer.zig
const std = @import("std");
const c = @import("c.zig").c;
const RenderTarget = @import("render_target.zig").RenderTarget;

pub const CullMode = enum {
    none,
    back,
    front,
};

pub const Renderer = struct {
    screen_quad_vao: c.GLuint,
    screen_quad_vbo: c.GLuint,

    const Self = @This();

    pub fn init() Self {
        // opengl global state
        c.glEnable(c.GL_DEPTH_TEST);
        c.glDepthFunc(c.GL_LESS);
        c.glEnable(c.GL_CULL_FACE);
        c.glCullFace(c.GL_BACK);
        c.glFrontFace(c.GL_CCW);

        // fullscreen quad
        const quad_verts = [_]f32{
            -1.0, 1.0,  0.0, 1.0,
            -1.0, -1.0, 0.0, 0.0,
            1.0,  -1.0, 1.0, 0.0,
            -1.0, 1.0,  0.0, 1.0,
            1.0,  -1.0, 1.0, 0.0,
            1.0,  1.0,  1.0, 1.0,
        };

        var vao: c.GLuint = undefined;
        var vbo: c.GLuint = undefined;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(quad_verts)), &quad_verts, c.GL_STATIC_DRAW);

        // position
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 4 * @sizeOf(f32), null);

        // uv
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, 4 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));

        c.glBindVertexArray(0);

        return .{
            .screen_quad_vao = vao,
            .screen_quad_vbo = vbo,
        };
    }

    pub fn deinit(self: *Self) void {
        c.glDeleteVertexArrays(1, &self.screen_quad_vao);
        c.glDeleteBuffers(1, &self.screen_quad_vbo);
    }

    // === state management ===

    pub fn setDepthTest(self: *Self, enabled: bool) void {
        _ = self;
        if (enabled) {
            c.glEnable(c.GL_DEPTH_TEST);
        } else {
            c.glDisable(c.GL_DEPTH_TEST);
        }
    }

    pub fn setCulling(self: *Self, mode: CullMode) void {
        _ = self;
        switch (mode) {
            .none => c.glDisable(c.GL_CULL_FACE),
            .back => {
                c.glEnable(c.GL_CULL_FACE);
                c.glCullFace(c.GL_BACK);
            },
            .front => {
                c.glEnable(c.GL_CULL_FACE);
                c.glCullFace(c.GL_FRONT);
            },
        }
    }

    pub fn setWireframe(self: *Self, enabled: bool) void {
        _ = self;
        if (enabled) {
            c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_LINE);
        } else {
            c.glPolygonMode(c.GL_FRONT_AND_BACK, c.GL_FILL);
        }
    }

    // === drawing ===

    pub fn drawFullscreenQuad(self: *Self) void {
        c.glBindVertexArray(self.screen_quad_vao);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);
        c.glBindVertexArray(0);
    }

    // === screen/window stuff ===
    //
    pub fn calculateViewport(window_w: u32, window_h: u32, render_w: f32, render_h: f32) struct { x: c.GLint, y: c.GLint, w: u32, h: u32 } {
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

    pub fn setViewport(self: *Self, x: i32, y: i32, width: u32, height: u32) void {
        _ = self;
        c.glViewport(x, y, @intCast(width), @intCast(height));
    }

    pub fn bindDefaultFramebuffer(self: *Self) void {
        _ = self;
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    }

    pub fn clearScreen(self: *Self, r: f32, g: f32, b: f32) void {
        _ = self;
        c.glClearColor(r, g, b, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);
    }
};
