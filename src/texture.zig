const c = @import("c.zig").c;
const std = @import("std");

pub const Texture = struct {
    id: c.GLuint,
    width: u32,
    height: u32,

    pub fn initRandom(allocator: std.mem.Allocator, width: u32, height: u32) !Texture {
        var id: c.GLuint = undefined;
        c.glGenTextures(1, &id);
        c.glBindTexture(c.GL_TEXTURE_2D, id);

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);

        var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
        const random = prng.random();

        const pixels = try allocator.alloc(u8, width * height);
        defer allocator.free(pixels);

        for (pixels) |*pixel| {
            pixel.* = if (random.boolean()) 255 else 0;
        }

        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_R8,
            @intCast(width),
            @intCast(height),
            0,
            c.GL_RED,
            c.GL_UNSIGNED_BYTE,
            pixels.ptr,
        );

        c.glBindTexture(c.GL_TEXTURE_2D, 0);

        return .{
            .id = id,
            .width = width,
            .height = height,
        };
    }

    pub fn bind(self: Texture, slot: c.GLuint) void {
        c.glActiveTexture(@intCast(c.GL_TEXTURE0 + @as(c_int, @intCast(slot))));
        c.glBindTexture(c.GL_TEXTURE_2D, self.id);
    }

    pub fn deinit(self: Texture) void {
        c.glDeleteTextures(1, &self.id);
    }
};
