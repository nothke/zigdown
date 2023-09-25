const std = @import("std");
const math = @import("mach").math;

r: f32 = 0,
g: f32 = 0,
b: f32 = 0,
a: f32 = 0,

const Color = @This();

pub fn init(r: f32, g: f32, b: f32, a: f32) Color {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

pub fn setA(self: Color, a: f32) Color {
    return .{
        .r = self.r,
        .g = self.g,
        .b = self.b,
        .a = a,
    };
}

pub fn multRGB(self: Color, mult: f32) Color {
    return .{
        .r = self.r * mult,
        .g = self.g * mult,
        .b = self.b * mult,
        .a = self.a,
    };
}

pub fn saturate(self: Color) Color {
    return .{
        .r = @max(@min(self.r, 1), 0),
        .g = @max(@min(self.g, 1), 0),
        .b = @max(@min(self.b, 1), 0),
        .a = @max(@min(self.a, 1), 0),
    };
}

pub fn asVec(self: Color) @Vector(4, f32) {
    return .{ self.r, self.g, self.b, self.a };
}

pub fn fromVec(v: @Vector(4, f32)) Color {
    return .{ .r = v[0], .g = v[1], .b = v[2], .a = v[3] };
}

pub fn toRGBVec3(self: Color) math.Vec3 {
    return .{ .v = .{ self.r, self.g, self.b } };
}

pub fn toVec4(self: Color) math.Vec4 {
    return .{ .v = asVec(self) };
}

pub fn from255(c: Color) Color {
    return .{
        .r = @as(f32, c.r) / 255,
        .g = @as(f32, c.g) / 255,
        .b = @as(f32, c.b) / 255,
        .a = @as(f32, c.a) / 255,
    };
}

pub const white = init(1, 1, 1, 1);
pub const black = init(0, 0, 0, 1);
pub const clear = init(0, 0, 0, 0);

// tests

const testing = std.testing;
const isEq = testing.expectEqual;

test "white" {
    try isEq(white.r, 1);
    try isEq(white.g, 1);
    try isEq(white.b, 1);
    try isEq(white.a, 1);

    try isEq(white.multRGB(0).r, 0);
}

test "blank" {
    var color = Color{};
    try isEq(color, fromVec(@Vector(4, f32){ 0, 0, 0, 0 }));
}

test "saturate" {
    var color = Color.init(0.3, -123, 23, 2);
    try isEq(color.saturate(), Color.init(0.3, 0, 1, 1));
}

test "complex comptime" {
    comptime var color = white.multRGB(23).saturate();

    try isEq(color.b, 1);
    comptime try isEq(color.b, 1);
}

test "vec3" {
    const color = white;
    const colorVec3 = color.toRGBVec3();
    try isEq(colorVec3, .{ .v = .{ 1, 1, 1 } });
}
