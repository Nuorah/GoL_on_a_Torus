const std = @import("std");
const c = @import("c.zig").c;
const InputEvent = @import("input.zig").InputEvent;
const Key = @import("input.zig").Key;
const MouseButton = @import("input.zig").MouseButton;

pub const WindowEvent = union(enum) {
    none,
    quit,
    input: InputEvent,
};

pub const Window = struct {
    const Self = @This();

    handle: *c.RGFW_window,
    width: u32,
    height: u32,
    is_fullscreen: bool,

    pub fn init(width: u32, height: u32, title: [*:0]const u8) !Self {
        const window = c.RGFW_createWindow(
            title,
            0,
            0,
            @intCast(width),
            @intCast(height),
            c.RGFW_windowCenter | c.RGFW_windowOpenGL,
        );

        if (window == null) {
            std.debug.print("failed to create window\n", .{});
            return error.WindowCreationFailed;
        }

        return Self{
            .handle = window.?,
            .width = width,
            .height = height,
            .is_fullscreen = false,
        };
    }

    pub fn deinit(self: *Self) void {
        c.RGFW_window_close(self.handle);
    }

    pub fn shouldClose(self: *Self) bool {
        return c.RGFW_window_shouldClose(self.handle) == c.RGFW_TRUE;
    }

    pub fn syncDimensions(self: *Self) void {
        self.width = @intCast(self.handle.*.w);
        self.height = @intCast(self.handle.*.h);
    }

    pub fn pollEvent(self: *Self) WindowEvent {
        var event: c.RGFW_event = undefined;
        if (c.RGFW_window_checkEvent(self.handle, &event) == c.RGFW_FALSE) {
            return .none;
        }

        return switch (event.type) {
            c.RGFW_quit => .quit,
            c.RGFW_keyPressed => .{ .input = .{ .key_down = translateKey(event.key.value) } },
            c.RGFW_keyReleased => .{ .input = .{ .key_up = translateKey(event.key.value) } },
            c.RGFW_mouseButtonPressed => .{ .input = .{ .mouse_down = translateMouseButton(event.button.value) } },
            c.RGFW_mouseButtonReleased => .{ .input = .{ .mouse_up = translateMouseButton(event.button.value) } },
            c.RGFW_mousePosChanged => .{
                .input = .{
                    .mouse_moved = .{
                        .x = event.mouse.x,
                        .y = event.mouse.y,
                        .dx = @intFromFloat(event.mouse.vecX),
                        .dy = @intFromFloat(event.mouse.vecY),
                    },
                },
            },
            else => .none,
        };
    }

    pub fn swapBuffers(self: *Self) void {
        c.RGFW_window_swapBuffers_OpenGL(self.handle);
    }

    pub fn toggleFullscreen(self: *Self) void {
        if (c.RGFW_window_isFullscreen(self.handle) == c.RGFW_TRUE) {
            c.RGFW_window_setFullscreen(self.handle, c.RGFW_FALSE);
            self.is_fullscreen = false;
        } else {
            c.RGFW_window_setFullscreen(self.handle, c.RGFW_TRUE);
            self.is_fullscreen = true;
        }
    }

    pub fn setVsync(self: *Self, enabled: bool) void {
        _ = self;
        c.RGFW_window_swapInterval(if (enabled) 1 else 0);
    }
};

fn translateKey(rgfw_key: u8) Key {
    return switch (rgfw_key) {
        c.RGFW_a => .a,
        c.RGFW_b => .b,
        c.RGFW_c => .c,
        c.RGFW_d => .d,
        c.RGFW_e => .e,
        c.RGFW_f => .f,
        c.RGFW_g => .g,
        c.RGFW_h => .h,
        c.RGFW_i => .i,
        c.RGFW_j => .j,
        c.RGFW_k => .k,
        c.RGFW_l => .l,
        c.RGFW_m => .m,
        c.RGFW_n => .n,
        c.RGFW_o => .o,
        c.RGFW_p => .p,
        c.RGFW_q => .q,
        c.RGFW_r => .r,
        c.RGFW_s => .s,
        c.RGFW_t => .t,
        c.RGFW_u => .u,
        c.RGFW_v => .v,
        c.RGFW_w => .w,
        c.RGFW_x => .x,
        c.RGFW_y => .y,
        c.RGFW_z => .z,
        c.RGFW_0 => .@"0",
        c.RGFW_1 => .@"1",
        c.RGFW_2 => .@"2",
        c.RGFW_3 => .@"3",
        c.RGFW_4 => .@"4",
        c.RGFW_5 => .@"5",
        c.RGFW_6 => .@"6",
        c.RGFW_7 => .@"7",
        c.RGFW_8 => .@"8",
        c.RGFW_9 => .@"9",
        c.RGFW_F1 => .f1,
        c.RGFW_F2 => .f2,
        c.RGFW_F3 => .f3,
        c.RGFW_F4 => .f4,
        c.RGFW_F5 => .f5,
        c.RGFW_F6 => .f6,
        c.RGFW_F7 => .f7,
        c.RGFW_F8 => .f8,
        c.RGFW_F9 => .f9,
        c.RGFW_F10 => .f10,
        c.RGFW_F11 => .f11,
        c.RGFW_F12 => .f12,
        c.RGFW_escape => .escape,
        c.RGFW_return => .enter,
        c.RGFW_space => .space,
        c.RGFW_backSpace => .backspace,
        c.RGFW_tab => .tab,
        c.RGFW_shiftL => .left_shift,
        c.RGFW_shiftR => .right_shift,
        c.RGFW_controlL => .left_ctrl,
        c.RGFW_controlR => .right_ctrl,
        c.RGFW_altL => .left_alt,
        c.RGFW_altR => .right_alt,
        c.RGFW_up => .up,
        c.RGFW_down => .down,
        c.RGFW_left => .left,
        c.RGFW_right => .right,
        c.RGFW_home => .home,
        c.RGFW_end => .end,
        c.RGFW_pageUp => .page_up,
        c.RGFW_pageDown => .page_down,
        c.RGFW_insert => .insert,
        c.RGFW_delete => .delete,
        else => .unknown,
    };
}

fn translateMouseButton(rgfw_button: u8) MouseButton {
    return switch (rgfw_button) {
        c.RGFW_mouseLeft => .left,
        c.RGFW_mouseRight => .right,
        c.RGFW_mouseMiddle => .middle,
        else => .left,
    };
}
