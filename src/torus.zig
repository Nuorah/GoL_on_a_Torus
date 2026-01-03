const std = @import("std");
const Vertex = @import("vertex.zig").Vertex;

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
