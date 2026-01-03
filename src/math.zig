const std = @import("std");

pub const Vec2 = struct {
    x: f32,
    y: f32,
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        return .{ .x = self.x / len, .y = self.y / len, .z = self.z / len };
    }
};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};

pub const Quat = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn identity() Quat {
        return .{ .x = 0, .y = 0, .z = 0, .w = 1 };
    }

    pub fn fromAxisAngle(axis: Vec3, angle: f32) Quat {
        const half = angle / 2.0;
        const s = @sin(half);
        const a = axis.normalize();
        return .{ .x = a.x * s, .y = a.y * s, .z = a.z * s, .w = @cos(half) };
    }

    pub fn multiply(self: Quat, other: Quat) Quat {
        return .{
            .x = self.w * other.x + self.x * other.w + self.y * other.z - self.z * other.y,
            .y = self.w * other.y - self.x * other.z + self.y * other.w + self.z * other.x,
            .z = self.w * other.z + self.x * other.y - self.y * other.x + self.z * other.w,
            .w = self.w * other.w - self.x * other.x - self.y * other.y - self.z * other.z,
        };
    }

    pub fn normalize(self: Quat) Quat {
        const len = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
        return .{ .x = self.x / len, .y = self.y / len, .z = self.z / len, .w = self.w / len };
    }

    pub fn slerp(a: Quat, b: Quat, t: f32) Quat {
        var cos_theta = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;

        var b_adj = b;
        if (cos_theta < 0.0) {
            cos_theta = -cos_theta;
            b_adj = .{ .x = -b.x, .y = -b.y, .z = -b.z, .w = -b.w };
        }

        if (cos_theta > 0.9995) {
            return (Quat{
                .x = a.x + t * (b_adj.x - a.x),
                .y = a.y + t * (b_adj.y - a.y),
                .z = a.z + t * (b_adj.z - a.z),
                .w = a.w + t * (b_adj.w - a.w),
            }).normalize();
        }

        const theta_0 = std.math.acos(cos_theta);
        const theta = theta_0 * t;
        const sin_theta = @sin(theta);
        const sin_theta_0 = @sin(theta_0);

        const s0 = @cos(theta) - cos_theta * sin_theta / sin_theta_0;
        const s1 = sin_theta / sin_theta_0;

        return .{
            .x = a.x * s0 + b_adj.x * s1,
            .y = a.y * s0 + b_adj.y * s1,
            .z = a.z * s0 + b_adj.z * s1,
            .w = a.w * s0 + b_adj.w * s1,
        };
    }

    pub fn toMat4(self: Quat) Mat4 {
        const xx = self.x * self.x;
        const yy = self.y * self.y;
        const zz = self.z * self.z;
        const xy = self.x * self.y;
        const xz = self.x * self.z;
        const yz = self.y * self.z;
        const wx = self.w * self.x;
        const wy = self.w * self.y;
        const wz = self.w * self.z;

        return .{ .data = .{
            1 - 2 * (yy + zz), 2 * (xy + wz),     2 * (xz - wy),     0,
            2 * (xy - wz),     1 - 2 * (xx + zz), 2 * (yz + wx),     0,
            2 * (xz + wy),     2 * (yz - wx),     1 - 2 * (xx + yy), 0,
            0,                 0,                 0,                 1,
        } };
    }
};

pub const Mat4 = struct {
    data: [16]f32,

    pub fn identity() Mat4 {
        return .{ .data = .{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        } };
    }

    pub fn translate(x: f32, y: f32, z: f32) Mat4 {
        return .{ .data = .{
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            x, y, z, 1,
        } };
    }

    pub fn scale(x: f32, y: f32, z: f32) Mat4 {
        return .{ .data = .{
            x, 0, 0, 0,
            0, y, 0, 0,
            0, 0, z, 0,
            0, 0, 0, 1,
        } };
    }

    pub fn perspective(fov_radians: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / @tan(fov_radians / 2.0);
        const nf = 1.0 / (near - far);
        return .{ .data = .{
            f / aspect, 0, 0,                     0,
            0,          f, 0,                     0,
            0,          0, (far + near) * nf,     -1,
            0,          0, 2.0 * far * near * nf, 0,
        } };
    }

    pub fn orthographic(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
        return .{ .data = .{
            2.0 / (right - left),             0,                                0,                            0,
            0,                                2.0 / (top - bottom),             0,                            0,
            0,                                0,                                -2.0 / (far - near),          0,
            -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(far + near) / (far - near), 1,
        } };
    }

    pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        const f = center.sub(eye).normalize();
        const s = f.cross(up).normalize();
        const u = s.cross(f);
        return .{ .data = .{
            s.x,         u.x,         -f.x,       0,
            s.y,         u.y,         -f.y,       0,
            s.z,         u.z,         -f.z,       0,
            -s.dot(eye), -u.dot(eye), f.dot(eye), 1,
        } };
    }

    pub fn multiply(self: Mat4, other: Mat4) Mat4 {
        var result: [16]f32 = undefined;
        comptime var i: usize = 0;
        inline while (i < 4) : (i += 1) {
            comptime var j: usize = 0;
            inline while (j < 4) : (j += 1) {
                result[j * 4 + i] =
                    self.data[0 * 4 + i] * other.data[j * 4 + 0] +
                    self.data[1 * 4 + i] * other.data[j * 4 + 1] +
                    self.data[2 * 4 + i] * other.data[j * 4 + 2] +
                    self.data[3 * 4 + i] * other.data[j * 4 + 3];
            }
        }
        return .{ .data = result };
    }
};
