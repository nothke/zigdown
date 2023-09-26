const std = @import("std");
const math = @import("mach").math;

r: f32 = 0,
g: f32 = 0,
b: f32 = 0,
a: f32 = 1,

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

pub fn toVec(self: Color) @Vector(4, f32) {
    return .{ self.r, self.g, self.b, self.a };
}

pub fn fromVec(v: @Vector(4, f32)) Color {
    return .{ .r = v[0], .g = v[1], .b = v[2], .a = v[3] };
}

pub fn toRGBVec3(self: Color) math.Vec3 {
    return .{ .v = .{ self.r, self.g, self.b } };
}

pub fn toVec4(self: Color) math.Vec4 {
    return .{ .v = toVec(self) };
}

pub fn from255(c: Color) Color {
    return fromVec(toVec(c) / @as(ColorV, @splat(255)));
}

const ColorV = @Vector(4, f32);
const ByteColorV = @Vector(4, u8);

pub fn fromByteV(v: ByteColorV) Color {
    return fromVec(@as(ColorV, @floatFromInt(v)) / @as(ColorV, @splat(255)));
}

const Error = error{
    HexMustBe8CharsLong,
};

pub fn fromHex(hex: []const u8) !Color {
    if (hex.len != 8 and hex.len != 6) {
        if (@inComptime()) {
            @compileError("Color hex code must be 8 characters long");
        } else {
            return Error.HexMustBe8CharsLong;
        }
    }

    const r = try std.fmt.parseInt(u8, hex[0..2], 16);
    const g = try std.fmt.parseInt(u8, hex[2..4], 16);
    const b = try std.fmt.parseInt(u8, hex[4..6], 16);
    const a = if (hex.len == 6) 255 else try std.fmt.parseInt(u8, hex[6..8], 16);

    return fromByteV(ByteColorV{ r, g, b, a });
}

pub const white = init(1, 1, 1, 1);
pub const black = init(0, 0, 0, 1);
pub const clear = init(0, 0, 0, 0);
pub const whiteClear = init(1, 1, 1, 0);

// Primary colors

pub const red = init(1, 0, 0, 1);
pub const green = init(0, 1, 0, 1);
pub const blue = init(0, 0, 1, 1);

// Secondary colors

pub const yellow = init(1, 1, 0, 1);
pub const cyan = init(0, 1, 1, 1);
pub const magenta = init(1, 0, 1, 1);

// Tertiary colors

pub const orange = init(1, 0.5, 0, 1);
pub const rose = init(1, 0, 0.5, 1);

pub const azure = init(0, 0.5, 1, 1);
pub const violet = init(0.5, 0, 1, 1);

pub const chartreuse = init(0.5, 1, 0, 1);
pub const lime = init(0.0, 1, 0.5, 1);

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
    try isEq(color, fromVec(@Vector(4, f32){ 0, 0, 0, 1 }));
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

test "ByteColor to Color" {
    const byteColor = ByteColorV{ 255, 0, 0, 255 };
    const color = fromByteV(byteColor);
    try isEq(red, color);
}

test "hex" {
    const hexColor = fromHex("ff0000ff");
    try isEq(hexColor, red);
}

test "comptime hex" {
    const hexColor = comptime fromHex("ff0000ff");
    try isEq(hexColor, red);
}

test "hex wrong length" {
    try testing.expectError(Error.HexMustBe8CharsLong, fromHex("ff00"));
}

test "hex 6 sized" {
    const hex = fromHex("00FF00");
    try isEq(hex, green);
}
