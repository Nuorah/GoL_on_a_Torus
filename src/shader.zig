const c = @import("c.zig").c;
const std = @import("std");

pub const Shader = struct {
    pub const Self = @This();

    name: []const u8,
    program: c.GLuint,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, vertex_path: []const u8, fragment_path: []const u8) !Self {
        const program = try createProgram(try loadFile(allocator, vertex_path), try loadFile(allocator, fragment_path));
        return Self{
            .name = name,
            .program = program,
        };
    }

    pub fn deinit(self: Self) void {
        c.glDeleteProgram(self.program);
    }

    pub fn use(self: Shader) void {
        c.glUseProgram(self.program);
    }

    pub fn setMat4(self: Shader, name: [*:0]const u8, mat: *const [16]f32) void {
        const loc = c.glGetUniformLocation(self.program, name);
        c.glUniformMatrix4fv(loc, 1, c.GL_FALSE, mat);
    }

    pub fn setVec2(self: Shader, name: [*:0]const u8, vec: *const [2]f32) void {
        const loc = c.glGetUniformLocation(self.program, name);
        c.glUniform2fv(loc, 1, vec); // no GL_FALSE here, that's for matrices
    }

    pub fn setInt(self: Shader, name: [*:0]const u8, value: i32) void {
        const loc = c.glGetUniformLocation(self.program, name);
        c.glUniform1i(loc, value);
    }
};

pub fn loadFile(allocator: std.mem.Allocator, path: []const u8) ![:0]u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        std.debug.print("Could not open file: {s}\n", .{path});
        return err;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.allocSentinel(u8, file_size, 0);
    var reader_buffer: [4096]u8 = undefined;
    var reader = file.reader(&reader_buffer);
    try reader.interface.readSliceAll(buffer);

    return buffer;
}

pub fn compileShader(source: [*:0]const u8, shader_type: c.GLenum) !c.GLuint {
    const shader = c.glCreateShader(shader_type);
    c.glShaderSource(shader, 1, &source, null);
    c.glCompileShader(shader);

    var success: c.GLint = 0;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);

    if (success == 0) {
        var info_log: [512]u8 = undefined;
        c.glGetShaderInfoLog(shader, 512, null, &info_log);

        const shader_type_str = if (shader_type == c.GL_VERTEX_SHADER)
            "VERTEX"
        else
            "FRAGMENT";

        std.debug.print("\n", .{});
        std.debug.print("========================================\n", .{});
        std.debug.print("{s} SHADER COMPILATION FAILED\n", .{shader_type_str});
        std.debug.print("========================================\n", .{});
        std.debug.print("{s}\n", .{info_log});
        std.debug.print("========================================\n", .{});

        c.glDeleteShader(shader);
        return error.ShaderCompilationFailed;
    }

    return shader;
}

pub fn createProgram(
    vertex_src: [*:0]const u8,
    fragment_src: [*:0]const u8,
) !c.GLuint {
    const vertex_shader = try compileShader(vertex_src, c.GL_VERTEX_SHADER);
    defer c.glDeleteShader(vertex_shader);

    const fragment_shader = try compileShader(fragment_src, c.GL_FRAGMENT_SHADER);
    defer c.glDeleteShader(fragment_shader);

    const program = c.glCreateProgram();
    c.glAttachShader(program, vertex_shader);
    c.glAttachShader(program, fragment_shader);
    c.glLinkProgram(program);

    var success: c.GLint = 0;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);

    if (success == 0) {
        var info_log: [512]u8 = undefined;
        c.glGetProgramInfoLog(program, 512, null, &info_log);

        std.debug.print("\n", .{});
        std.debug.print("========================================\n", .{});
        std.debug.print("SHADER LINKING FAILED\n", .{});
        std.debug.print("========================================\n", .{});
        std.debug.print("{s}\n", .{info_log});
        std.debug.print("========================================\n", .{});

        c.glDeleteProgram(program);
        return error.ShaderLinkingFailed;
    }

    return program;
}
