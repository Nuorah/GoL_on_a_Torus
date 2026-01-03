const std = @import("std");
const math = @import("math.zig");

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

pub const Model = struct {
    vertices: []Vec3,
    uvs: []Vec2,
    faces: [][3]u32,
    normals: []Vec3,
};
