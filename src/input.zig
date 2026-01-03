const std = @import("std");

pub const Key = enum {
    // letters
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,

    // numbers
    @"0",
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",

    // function keys
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,

    // modifiers
    left_shift,
    right_shift,
    left_ctrl,
    right_ctrl,
    left_alt,
    right_alt,

    // navigation
    up,
    down,
    left,
    right,
    home,
    end,
    page_up,
    page_down,
    insert,
    delete,

    // common
    escape,
    enter,
    space,
    backspace,
    tab,

    // misc
    grave,
    minus,
    equals,
    left_bracket,
    right_bracket,
    backslash,
    semicolon,
    apostrophe,
    comma,
    period,
    slash,

    unknown,
};

pub const MouseButton = enum {
    left,
    right,
    middle,
    x1,
    x2,
};

pub const InputEvent = union(enum) {
    key_down: Key,
    key_up: Key,
    mouse_down: MouseButton,
    mouse_up: MouseButton,
    mouse_moved: struct { x: i32, y: i32, dx: i32, dy: i32 },
    mouse_scroll: struct { dx: f32, dy: f32 },
};

pub const Input = struct {
    const Self = @This();

    keys_held: std.EnumSet(Key),
    keys_pressed: std.EnumSet(Key), // went down THIS frame
    keys_released: std.EnumSet(Key), // went up THIS frame

    mouse_buttons_held: std.EnumSet(MouseButton),
    mouse_buttons_pressed: std.EnumSet(MouseButton),
    mouse_buttons_released: std.EnumSet(MouseButton),

    mouse_x: i32,
    mouse_y: i32,
    mouse_dx: i32,
    mouse_dy: i32,
    scroll_dx: f32,
    scroll_dy: f32,

    pub fn init() Self {
        return Self{
            .keys_held = std.EnumSet(Key).initEmpty(),
            .keys_pressed = std.EnumSet(Key).initEmpty(),
            .keys_released = std.EnumSet(Key).initEmpty(),
            .mouse_buttons_held = std.EnumSet(MouseButton).initEmpty(),
            .mouse_buttons_pressed = std.EnumSet(MouseButton).initEmpty(),
            .mouse_buttons_released = std.EnumSet(MouseButton).initEmpty(),
            .mouse_x = 0,
            .mouse_y = 0,
            .mouse_dx = 0,
            .mouse_dy = 0,
            .scroll_dx = 0,
            .scroll_dy = 0,
        };
    }

    /// call at START of frame before polling events
    pub fn newFrame(self: *Self) void {
        self.keys_pressed = std.EnumSet(Key).initEmpty();
        self.keys_released = std.EnumSet(Key).initEmpty();
        self.mouse_buttons_pressed = std.EnumSet(MouseButton).initEmpty();
        self.mouse_buttons_released = std.EnumSet(MouseButton).initEmpty();
        self.mouse_dx = 0;
        self.mouse_dy = 0;
        self.scroll_dx = 0;
        self.scroll_dy = 0;
    }

    pub fn handleEvent(self: *Self, event: InputEvent) void {
        switch (event) {
            .key_down => |key| {
                if (!self.keys_held.contains(key)) {
                    self.keys_pressed.insert(key);
                }
                self.keys_held.insert(key);
            },
            .key_up => |key| {
                if (self.keys_held.contains(key)) {
                    self.keys_released.insert(key);
                }
                self.keys_held.remove(key);
            },
            .mouse_down => |btn| {
                if (!self.mouse_buttons_held.contains(btn)) {
                    self.mouse_buttons_pressed.insert(btn);
                }
                self.mouse_buttons_held.insert(btn);
            },
            .mouse_up => |btn| {
                if (self.mouse_buttons_held.contains(btn)) {
                    self.mouse_buttons_released.insert(btn);
                }
                self.mouse_buttons_held.remove(btn);
            },
            .mouse_moved => |m| {
                self.mouse_x = m.x;
                self.mouse_y = m.y;
                self.mouse_dx += m.dx;
                self.mouse_dy += m.dy;
            },
            .mouse_scroll => |s| {
                self.scroll_dx += s.dx;
                self.scroll_dy += s.dy;
            },
        }
    }

    // === query API ===

    pub fn isKeyHeld(self: Self, key: Key) bool {
        return self.keys_held.contains(key);
    }

    pub fn isKeyPressed(self: Self, key: Key) bool {
        return self.keys_pressed.contains(key);
    }

    pub fn isKeyReleased(self: Self, key: Key) bool {
        return self.keys_released.contains(key);
    }

    pub fn isMouseButtonHeld(self: Self, btn: MouseButton) bool {
        return self.mouse_buttons_held.contains(btn);
    }

    pub fn isMouseButtonPressed(self: Self, btn: MouseButton) bool {
        return self.mouse_buttons_pressed.contains(btn);
    }

    pub fn isMouseButtonReleased(self: Self, btn: MouseButton) bool {
        return self.mouse_buttons_released.contains(btn);
    }

    /// WASD/arrow movement as normalized vector
    pub fn getMoveDir(self: Self) struct { x: f32, y: f32 } {
        var x: f32 = 0;
        var y: f32 = 0;

        if (self.isKeyHeld(.w) or self.isKeyHeld(.up)) y += 1;
        if (self.isKeyHeld(.s) or self.isKeyHeld(.down)) y -= 1;
        if (self.isKeyHeld(.a) or self.isKeyHeld(.left)) x -= 1;
        if (self.isKeyHeld(.d) or self.isKeyHeld(.right)) x += 1;

        // normalize diagonal movement
        if (x != 0 and y != 0) {
            const inv_sqrt2 = 0.7071067811865475;
            x *= inv_sqrt2;
            y *= inv_sqrt2;
        }

        return .{ .x = x, .y = y };
    }
};
