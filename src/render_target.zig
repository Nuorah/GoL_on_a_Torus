const c = @import("c.zig").c;

pub const TextureFormat = enum {
    rgb, // regular color
    r8, // single channel (GoL grid)
};

pub const RenderTarget = struct {
    fbo: c.GLuint,
    texture: c.GLuint,
    depth: c.GLuint,
    width: u32,
    height: u32,
    has_depth: bool,

    pub fn init(width: u32, height: u32, format: TextureFormat, with_depth: bool) RenderTarget {
        var fbo: c.GLuint = undefined;
        var texture: c.GLuint = undefined;
        var depth: c.GLuint = 0;

        c.glGenFramebuffers(1, &fbo);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, fbo);

        // color texture
        c.glGenTextures(1, &texture);
        c.glBindTexture(c.GL_TEXTURE_2D, texture);

        const internal_format: c.GLint = switch (format) {
            .rgb => c.GL_RGB,
            .r8 => c.GL_R8,
        };
        const pixel_format: c.GLenum = switch (format) {
            .rgb => c.GL_RGB,
            .r8 => c.GL_RED,
        };

        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            internal_format,
            @intCast(width),
            @intCast(height),
            0,
            pixel_format,
            c.GL_UNSIGNED_BYTE,
            null,
        );

        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
        c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_COLOR_ATTACHMENT0, c.GL_TEXTURE_2D, texture, 0);

        if (with_depth) {
            c.glGenRenderbuffers(1, &depth);
            c.glBindRenderbuffer(c.GL_RENDERBUFFER, depth);
            c.glRenderbufferStorage(c.GL_RENDERBUFFER, c.GL_DEPTH_COMPONENT24, @intCast(width), @intCast(height));
            c.glFramebufferRenderbuffer(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_RENDERBUFFER, depth);
        }

        if (c.glCheckFramebufferStatus(c.GL_FRAMEBUFFER) != c.GL_FRAMEBUFFER_COMPLETE) {
            @panic("Framebuffer not complete");
        }

        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);

        return .{
            .fbo = fbo,
            .texture = texture,
            .depth = depth,
            .width = width,
            .height = height,
            .has_depth = with_depth,
        };
    }

    pub fn bind(self: RenderTarget) void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.fbo);
        c.glViewport(0, 0, @intCast(self.width), @intCast(self.height));
    }

    pub fn bindTexture(self: RenderTarget, slot: c.GLuint) void {
        const gl_slot: c.GLenum = @intCast(@as(c_int, c.GL_TEXTURE0) + @as(c_int, @intCast(slot)));
        c.glActiveTexture(gl_slot);
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
    }

    pub fn unbindFramebuffer() void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    }

    pub fn deinit(self: RenderTarget) void {
        c.glDeleteFramebuffers(1, &self.fbo);
        c.glDeleteTextures(1, &self.texture);
        if (self.has_depth) {
            c.glDeleteRenderbuffers(1, &self.depth);
        }
    }
};
