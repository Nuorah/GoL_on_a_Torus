const math = @import("math.zig");
const Mat4 = math.Mat4;
const Vec3 = math.Vec3;
const Vec2 = math.Vec2;
const std = @import("std");

pub const ProjectionType = enum {
    perspective,
    orthographic,
};

pub const Camera = struct {
    position: Vec3,
    target: Vec3,
    up: Vec3,

    // orbit params
    orbit_angle_h: f32 = 0, // horizontal (around Y axis)
    orbit_angle_v: f32 = 0.3, // vertical (pitch), start slightly above
    orbit_distance: f32 = 15,
    orbit_speed: f32 = 2.0,

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

    pub fn updateOrbit(self: *Camera, move_dir: Vec2, zoom: f32, delta: f32) void {
        self.orbit_angle_h += move_dir.x * self.orbit_speed * delta;
        self.orbit_angle_v += move_dir.y * self.orbit_speed * delta;

        self.orbit_distance -= zoom * self.orbit_speed * 2.0 * delta;
        self.orbit_distance = std.math.clamp(self.orbit_distance, 4.0, 50.0);

        // clamp vertical to avoid gimbal lock / flipping
        const max_pitch = std.math.pi / 2.0 - 0.1;
        self.orbit_angle_v = std.math.clamp(self.orbit_angle_v, -max_pitch, max_pitch);

        // spherical to cartesian
        const cos_v = @cos(self.orbit_angle_v);
        self.position = .{
            .x = @sin(self.orbit_angle_h) * cos_v * self.orbit_distance,
            .y = @sin(self.orbit_angle_v) * self.orbit_distance,
            .z = @cos(self.orbit_angle_h) * cos_v * self.orbit_distance,
        };
        // target stays at origin (torus center)
    }
};
