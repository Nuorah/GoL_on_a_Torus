const math = @import("math.zig");
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const std = @import("std");

pub const ProjectionType = enum {
    perspective,
    orthographic,
};

pub const Camera = struct {
    position: Vec3,
    target: Vec3,
    up: Vec3,

    // perspective params
    fov: f32,
    aspect: f32,

    // orthographic params
    ortho_size: f32, // half-height of the view

    // shared
    near: f32,
    far: f32,
    projection_type: ProjectionType,

    pub fn init(aspect: f32) Camera {
        return .{
            .position = .{ .x = 0, .y = 0, .z = 15 },
            .target = .{ .x = 0, .y = 0, .z = 0 },
            .up = .{ .x = 0, .y = 1, .z = 0 },
            .fov = std.math.pi / 8.0,
            .aspect = aspect,
            .ortho_size = 2.0,
            .near = 0.1,
            .far = 200.0,
            .projection_type = .perspective,
        };
    }

    pub fn getViewMatrix(self: Camera) Mat4 {
        return Mat4.lookAt(self.position, self.target, self.up);
    }

    pub fn getProjectionMatrix(self: Camera) Mat4 {
        return switch (self.projection_type) {
            .perspective => Mat4.perspective(self.fov, self.aspect, self.near, self.far),
            .orthographic => blk: {
                const h = self.ortho_size;
                const w = h * self.aspect;
                break :blk Mat4.orthographic(-w, w, -h, h, self.near, self.far);
            },
        };
    }
};
