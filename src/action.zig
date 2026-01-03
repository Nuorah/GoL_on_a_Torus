const std = @import("std");
const Input = @import("input.zig").Input;
const Key = @import("input.zig").Key;
const MouseButton = @import("input.zig").MouseButton;

pub const Action = enum {
    move_up,
    move_down,
    move_left,
    move_right,
    reset,
    toggle_fullscreen,
    quit,
};

pub const Binding = union(enum) {
    key: Key,
    mouse: MouseButton,
};

pub const ActionMap = struct {
    const Self = @This();

    bindings: std.EnumArray(Action, ?Binding),

    pub fn init() Self {
        var self = Self{
            .bindings = std.EnumArray(Action, ?Binding).initFill(null),
        };

        // defaults
        self.bindings.set(.move_up, .{ .key = .w });
        self.bindings.set(.move_down, .{ .key = .s });
        self.bindings.set(.move_left, .{ .key = .a });
        self.bindings.set(.move_right, .{ .key = .d });
        self.bindings.set(.reset, .{ .key = .r });
        self.bindings.set(.toggle_fullscreen, .{ .key = .f11 });
        self.bindings.set(.quit, .{ .key = .escape });

        return self;
    }

    pub fn isHeld(self: Self, input: Input, action: Action) bool {
        const binding = self.bindings.get(action) orelse return false;
        return switch (binding) {
            .key => |k| input.isKeyHeld(k),
            .mouse => |m| input.isMouseButtonHeld(m),
        };
    }

    pub fn isPressed(self: Self, input: Input, action: Action) bool {
        const binding = self.bindings.get(action) orelse return false;
        return switch (binding) {
            .key => |k| input.isKeyPressed(k),
            .mouse => |m| input.isMouseButtonPressed(m),
        };
    }

    pub fn getMoveDir(self: Self, input: Input) struct { x: f32, y: f32 } {
        var x: f32 = 0;
        var y: f32 = 0;

        if (self.isHeld(input, .move_up)) y += 1;
        if (self.isHeld(input, .move_down)) y -= 1;
        if (self.isHeld(input, .move_left)) x -= 1;
        if (self.isHeld(input, .move_right)) x += 1;

        if (x != 0 and y != 0) {
            const inv_sqrt2 = 0.7071067811865475;
            x *= inv_sqrt2;
            y *= inv_sqrt2;
        }

        return .{ .x = x, .y = y };
    }
};
