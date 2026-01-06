const c = @import("c.zig").c;

pub const TextureFormat = enum {
    rgb, // standard color
    rgba, // color + alpha
    r8, // single channel
    depth, // depth-only
};

pub const RenderTarget = struct {
    fbo: c.GLuint,
    texture: c.GLuint,
    depth: c.GLuint,
    width: u32,
    height: u32,
    format: TextureFormat,

    pub fn init(width: u32, height: u32, format: TextureFormat, with_depth: bool) RenderTarget {
        var fbo: c.GLuint = undefined;
        var texture: c.GLuint = undefined;
        var depth: c.GLuint = 0;

        c.glGenFramebuffers(1, &fbo);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, fbo);

        c.glGenTextures(1, &texture);
        c.glBindTexture(c.GL_TEXTURE_2D, texture);

        if (format == .depth) {
            c.glTexImage2D(
                c.GL_TEXTURE_2D,
                0,
                c.GL_DEPTH_COMPONENT24,
                @intCast(width),
                @intCast(height),
                0,
                c.GL_DEPTH_COMPONENT,
                c.GL_FLOAT,
                null,
            );
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_BORDER);
            c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_BORDER);
            const border = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
            c.glTexParameterfv(c.GL_TEXTURE_2D, c.GL_TEXTURE_BORDER_COLOR, &border);

            c.glFramebufferTexture2D(c.GL_FRAMEBUFFER, c.GL_DEPTH_ATTACHMENT, c.GL_TEXTURE_2D, texture, 0);
            c.glDrawBuffer(c.GL_NONE);
            c.glReadBuffer(c.GL_NONE);
        } else {
            const internal_format: c.GLint = switch (format) {
                .rgb => c.GL_RGB,
                .rgba => c.GL_RGBA,
                .r8 => c.GL_R8,
                .depth => unreachable,
            };
            const pixel_format: c.GLenum = switch (format) {
                .rgb => c.GL_RGB,
                .rgba => c.GL_RGBA,
                .r8 => c.GL_RED,
                .depth => unreachable,
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
            .format = format,
        };
    }

    pub fn bind(self: RenderTarget) void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.fbo);
        c.glViewport(0, 0, @intCast(self.width), @intCast(self.height));
    }

    pub fn clear(self: RenderTarget, color: ?[4]f32) void {
        self.bind();
        var bits: c.GLbitfield = 0;
        if (color) |col| {
            c.glClearColor(col[0], col[1], col[2], col[3]);
            bits |= c.GL_COLOR_BUFFER_BIT;
        }
        if (self.depth != 0 or self.format == .depth) {
            bits |= c.GL_DEPTH_BUFFER_BIT;
        }
        if (bits != 0) c.glClear(bits);
    }

    pub fn bindTexture(self: RenderTarget, slot: c.GLuint) void {
        const gl_slot: c.GLenum = @intCast(@as(c_int, c.GL_TEXTURE0) + @as(c_int, @intCast(slot)));
        c.glActiveTexture(gl_slot);
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
    }

    pub fn uploadPixels(self: *const RenderTarget, pixels: []const u8) void {
        const pixel_format: c.GLenum = switch (self.format) {
            .rgb => c.GL_RGB,
            .rgba => c.GL_RGBA,
            .r8 => c.GL_RED,
            .depth => return, // can't upload to depth like this
        };

        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        c.glTexSubImage2D(
            c.GL_TEXTURE_2D,
            0,
            0,
            0,
            @intCast(self.width),
            @intCast(self.height),
            pixel_format,
            c.GL_UNSIGNED_BYTE,
            pixels.ptr,
        );
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
    }

    pub fn unbind() void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    }

    pub fn deinit(self: RenderTarget) void {
        c.glDeleteFramebuffers(1, &self.fbo);
        c.glDeleteTextures(1, &self.texture);
        if (self.depth != 0) {
            c.glDeleteRenderbuffers(1, &self.depth);
        }
    }
};
