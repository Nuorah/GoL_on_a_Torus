const c = @import("c.zig").c;
const Vertex = @import("vertex.zig").Vertex;

pub const Mesh = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,
    index_count: u32,
    instance_vbo: c.GLuint = 0,

    pub fn init(vertices: []const Vertex, indices: []const u32) Mesh {
        var vao: c.GLuint = undefined;
        var vbo: c.GLuint = undefined;
        var ebo: c.GLuint = undefined;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glGenBuffers(1, &ebo);

        c.glBindVertexArray(vao);

        // upload vertex data
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @intCast(vertices.len * @sizeOf(Vertex)),
            vertices.ptr,
            c.GL_STATIC_DRAW,
        );

        // upload index data
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        c.glBufferData(
            c.GL_ELEMENT_ARRAY_BUFFER,
            @intCast(indices.len * @sizeOf(u32)),
            indices.ptr,
            c.GL_STATIC_DRAW,
        );

        const stride: c.GLsizei = @sizeOf(Vertex);

        // position: location 0
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(0));
        c.glEnableVertexAttribArray(0);

        // uv: location 1
        c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(3 * @sizeOf(f32)));
        c.glEnableVertexAttribArray(1);

        // normal: location 2
        c.glVertexAttribPointer(2, 3, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(5 * @sizeOf(f32)));
        c.glEnableVertexAttribArray(2);

        // tangent: location 3
        c.glVertexAttribPointer(3, 4, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(8 * @sizeOf(f32)));
        c.glEnableVertexAttribArray(3);

        // bone_ids: location 4 (as integers)
        c.glVertexAttribIPointer(4, 4, c.GL_UNSIGNED_BYTE, stride, @ptrFromInt(12 * @sizeOf(f32)));
        c.glEnableVertexAttribArray(4);

        // bone_weights: location 5
        c.glVertexAttribPointer(5, 4, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(12 * @sizeOf(f32) + 4));
        c.glEnableVertexAttribArray(5);

        c.glBindVertexArray(0);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);

        return Mesh{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .index_count = @intCast(indices.len),
        };
    }

    pub fn deinit(self: Mesh) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteBuffers(1, &self.ebo);
        if (self.instance_vbo != 0) {
            c.glDeleteBuffers(1, &self.instance_vbo);
        }
    }

    pub fn draw(self: Mesh) void {
        c.glBindVertexArray(self.vao);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(self.index_count), c.GL_UNSIGNED_INT, null);
    }
};
