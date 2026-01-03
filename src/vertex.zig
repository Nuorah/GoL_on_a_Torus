pub const Vertex = struct {
    position: [3]f32,
    uv: [2]f32,
    normal: [3]f32,
    tangent: [4]f32,
    bone_ids: [4]u8,
    bone_weights: [4]f32,
};
