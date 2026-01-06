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

    handle: *c.GLFWwindow,
    width: u32,
    height: u32,
    is_fullscreen: bool,
    is_vsync: bool,
    saved_pos: struct { x: c_int, y: c_int },
    saved_size: struct { w: c_int, h: c_int },

    // event queue for polling
    event_queue: [64]WindowEvent,
    event_head: usize,
    event_tail: usize,

    pub fn init(width: u32, height: u32, title: [*:0]const u8) !Self {
        if (c.glfwInit() == c.GLFW_FALSE) {
            std.debug.print("failed to init glfw\n", .{});
            return error.GLFWInitFailed;
        }

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

        const window = c.glfwCreateWindow(
            @intCast(width),
            @intCast(height),
            title,
            null,
            null,
        );

        if (window == null) {
            std.debug.print("failed to create window\n", .{});
            c.glfwTerminate();
            return error.WindowCreationFailed;
        }

        c.glfwMakeContextCurrent(window);

        return Self{
            .handle = window.?,
            .width = width,
            .height = height,
            .is_fullscreen = false,
            .is_vsync = true,
            .saved_pos = .{ .x = 0, .y = 0 },
            .saved_size = .{ .w = @intCast(width), .h = @intCast(height) },
            .event_queue = undefined,
            .event_head = 0,
            .event_tail = 0,
        };
    }

    pub fn setupCallbacks(self: *Self) void {
        // store self pointer for callbacks
        c.glfwSetWindowUserPointer(self.handle, self);
        _ = c.glfwSetKeyCallback(self.handle, keyCallback);
        _ = c.glfwSetMouseButtonCallback(self.handle, mouseButtonCallback);
        _ = c.glfwSetCursorPosCallback(self.handle, cursorPosCallback);
        _ = c.glfwSetScrollCallback(self.handle, scrollCallback);
        _ = c.glfwSetWindowCloseCallback(self.handle, closeCallback);
    }

    pub fn deinit(self: *Self) void {
        c.glfwDestroyWindow(self.handle);
        c.glfwTerminate();
    }

    pub fn shouldClose(self: *Self) bool {
        return c.glfwWindowShouldClose(self.handle) == c.GLFW_TRUE;
    }

    pub fn syncDimensions(self: *Self) void {
        var w: c_int = 0;
        var h: c_int = 0;
        c.glfwGetFramebufferSize(self.handle, &w, &h);
        self.width = @intCast(w);
        self.height = @intCast(h);
    }

    pub fn pollEvent(self: *Self) WindowEvent {
        c.glfwPollEvents();

        if (self.event_head != self.event_tail) {
            const event = self.event_queue[self.event_tail];
            self.event_tail = (self.event_tail + 1) % self.event_queue.len;
            return event;
        }

        return .none;
    }

    pub fn swapBuffers(self: *Self) void {
        c.glfwSwapBuffers(self.handle);
    }

    pub fn toggleFullscreen(self: *Self) void {
        if (self.is_fullscreen) {
            c.glfwSetWindowMonitor(
                self.handle,
                null,
                self.saved_pos.x,
                self.saved_pos.y,
                self.saved_size.w,
                self.saved_size.h,
                c.GLFW_DONT_CARE,
            );
            self.is_fullscreen = false;
        } else {
            c.glfwGetWindowPos(self.handle, &self.saved_pos.x, &self.saved_pos.y);
            c.glfwGetWindowSize(self.handle, &self.saved_size.w, &self.saved_size.h);

            const monitor = c.glfwGetPrimaryMonitor();
            const mode = c.glfwGetVideoMode(monitor);
            c.glfwSetWindowMonitor(
                self.handle,
                monitor,
                0,
                0,
                mode.*.width,
                mode.*.height,
                mode.*.refreshRate,
            );
            self.is_fullscreen = true;
        }
    }

    pub fn toggleVsync(self: *Self) void {
        if (self.is_vsync) {
            c.glfwSwapInterval(0);
            self.is_vsync = false;
        } else {
            c.glfwSwapInterval(1);
            self.is_vsync = true;
        }
    }

    fn pushEvent(self: *Self, event: WindowEvent) void {
        const next_head = (self.event_head + 1) % self.event_queue.len;
        if (next_head == self.event_tail) return; // queue full, drop event
        self.event_queue[self.event_head] = event;
        self.event_head = next_head;
    }

    fn keyCallback(window: ?*c.GLFWwindow, key: c_int, _: c_int, action: c_int, _: c_int) callconv(.c) void {
        const self = getSelf(window) orelse return;
        const translated = translateKey(key);

        if (action == c.GLFW_PRESS) {
            self.pushEvent(.{ .input = .{ .key_down = translated } });
        } else if (action == c.GLFW_RELEASE) {
            self.pushEvent(.{ .input = .{ .key_up = translated } });
        }
    }

    fn mouseButtonCallback(window: ?*c.GLFWwindow, button: c_int, action: c_int, _: c_int) callconv(.c) void {
        const self = getSelf(window) orelse return;
        const translated = translateMouseButton(button);

        if (action == c.GLFW_PRESS) {
            self.pushEvent(.{ .input = .{ .mouse_down = translated } });
        } else if (action == c.GLFW_RELEASE) {
            self.pushEvent(.{ .input = .{ .mouse_up = translated } });
        }
    }

    var last_mouse_x: f64 = 0;
    var last_mouse_y: f64 = 0;
    var first_mouse: bool = true;

    fn cursorPosCallback(window: ?*c.GLFWwindow, xpos: f64, ypos: f64) callconv(.c) void {
        const self = getSelf(window) orelse return;

        if (first_mouse) {
            last_mouse_x = xpos;
            last_mouse_y = ypos;
            first_mouse = false;
        }

        const dx = xpos - last_mouse_x;
        const dy = ypos - last_mouse_y;
        last_mouse_x = xpos;
        last_mouse_y = ypos;

        self.pushEvent(.{
            .input = .{
                .mouse_moved = .{
                    .x = @intFromFloat(xpos),
                    .y = @intFromFloat(ypos),
                    .dx = @intFromFloat(dx),
                    .dy = @intFromFloat(dy),
                },
            },
        });
    }

    fn scrollCallback(window: ?*c.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.c) void {
        const self = getSelf(window) orelse return;
        self.pushEvent(.{
            .input = .{
                .mouse_scroll = .{
                    .dx = @floatCast(xoffset),
                    .dy = @floatCast(yoffset),
                },
            },
        });
    }

    fn closeCallback(window: ?*c.GLFWwindow) callconv(.c) void {
        const self = getSelf(window) orelse return;
        self.pushEvent(.quit);
    }

    fn getSelf(window: ?*c.GLFWwindow) ?*Self {
        if (window) |w| {
            return @ptrCast(@alignCast(c.glfwGetWindowUserPointer(w)));
        }
        return null;
    }
};

fn translateKey(glfw_key: c_int) Key {
    return switch (glfw_key) {
        c.GLFW_KEY_A => .a,
        c.GLFW_KEY_B => .b,
        c.GLFW_KEY_C => .c,
        c.GLFW_KEY_D => .d,
        c.GLFW_KEY_E => .e,
        c.GLFW_KEY_F => .f,
        c.GLFW_KEY_G => .g,
        c.GLFW_KEY_H => .h,
        c.GLFW_KEY_I => .i,
        c.GLFW_KEY_J => .j,
        c.GLFW_KEY_K => .k,
        c.GLFW_KEY_L => .l,
        c.GLFW_KEY_M => .m,
        c.GLFW_KEY_N => .n,
        c.GLFW_KEY_O => .o,
        c.GLFW_KEY_P => .p,
        c.GLFW_KEY_Q => .q,
        c.GLFW_KEY_R => .r,
        c.GLFW_KEY_S => .s,
        c.GLFW_KEY_T => .t,
        c.GLFW_KEY_U => .u,
        c.GLFW_KEY_V => .v,
        c.GLFW_KEY_W => .w,
        c.GLFW_KEY_X => .x,
        c.GLFW_KEY_Y => .y,
        c.GLFW_KEY_Z => .z,
        c.GLFW_KEY_0 => .@"0",
        c.GLFW_KEY_1 => .@"1",
        c.GLFW_KEY_2 => .@"2",
        c.GLFW_KEY_3 => .@"3",
        c.GLFW_KEY_4 => .@"4",
        c.GLFW_KEY_5 => .@"5",
        c.GLFW_KEY_6 => .@"6",
        c.GLFW_KEY_7 => .@"7",
        c.GLFW_KEY_8 => .@"8",
        c.GLFW_KEY_9 => .@"9",
        c.GLFW_KEY_F1 => .f1,
        c.GLFW_KEY_F2 => .f2,
        c.GLFW_KEY_F3 => .f3,
        c.GLFW_KEY_F4 => .f4,
        c.GLFW_KEY_F5 => .f5,
        c.GLFW_KEY_F6 => .f6,
        c.GLFW_KEY_F7 => .f7,
        c.GLFW_KEY_F8 => .f8,
        c.GLFW_KEY_F9 => .f9,
        c.GLFW_KEY_F10 => .f10,
        c.GLFW_KEY_F11 => .f11,
        c.GLFW_KEY_F12 => .f12,
        c.GLFW_KEY_ESCAPE => .escape,
        c.GLFW_KEY_ENTER => .enter,
        c.GLFW_KEY_SPACE => .space,
        c.GLFW_KEY_BACKSPACE => .backspace,
        c.GLFW_KEY_TAB => .tab,
        c.GLFW_KEY_LEFT_SHIFT => .left_shift,
        c.GLFW_KEY_RIGHT_SHIFT => .right_shift,
        c.GLFW_KEY_LEFT_CONTROL => .left_ctrl,
        c.GLFW_KEY_RIGHT_CONTROL => .right_ctrl,
        c.GLFW_KEY_LEFT_ALT => .left_alt,
        c.GLFW_KEY_RIGHT_ALT => .right_alt,
        c.GLFW_KEY_UP => .up,
        c.GLFW_KEY_DOWN => .down,
        c.GLFW_KEY_LEFT => .left,
        c.GLFW_KEY_RIGHT => .right,
        c.GLFW_KEY_HOME => .home,
        c.GLFW_KEY_END => .end,
        c.GLFW_KEY_PAGE_UP => .page_up,
        c.GLFW_KEY_PAGE_DOWN => .page_down,
        c.GLFW_KEY_INSERT => .insert,
        c.GLFW_KEY_DELETE => .delete,
        else => .unknown,
    };
}

fn translateMouseButton(glfw_button: c_int) MouseButton {
    return switch (glfw_button) {
        c.GLFW_MOUSE_BUTTON_LEFT => .left,
        c.GLFW_MOUSE_BUTTON_RIGHT => .right,
        c.GLFW_MOUSE_BUTTON_MIDDLE => .middle,
        else => .left,
    };
}
