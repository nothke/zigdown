const std = @import("std");
const math = @import("mach").math;

const ColorMethods = @This();

pub const Color = extern struct {
    r: f32 = 0,
    g: f32 = 0,
    b: f32 = 0,
    a: f32 = 1,

    pub usingnamespace ColorMethods;
};

const f32x4 = @Vector(4, f32);
const u8x4 = @Vector(4, u8);

// Color constants

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

const Error = error{
    HexMustBe6or8CharsLong,
};

// Methods

pub fn init(r: f32, g: f32, b: f32, a: f32) Color {
    return .{ .r = r, .g = g, .b = b, .a = a };
}

// modifiers

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
    const min = @min(self.toVec(), vecFromScalar(1));
    return fromVec(@max(min, vecFromScalar(0)));
}

// conversion

pub fn fromVec(v: f32x4) Color {
    return @bitCast(v);
}

pub fn toVec(self: Color) f32x4 {
    return @bitCast(self);
}

pub fn fromU8x4(v: u8x4) Color {
    return fromVec(@as(f32x4, @floatFromInt(v)) / vecFromScalar(255));
}

pub fn toU8x4(c: Color) u8x4 {
    return @as(u8x4, @intFromFloat(toVec(c.saturate()) * vecFromScalar(255)));
}

pub fn vecFromScalar(scalar: f32) f32x4 {
    return @splat(scalar);
}

pub fn toRGBVec3(self: Color) math.Vec3 {
    return .{ .v = .{ self.r, self.g, self.b } };
}

pub fn toVec4(self: Color) math.Vec4 {
    return @bitCast(self);
}

pub fn from255(c: Color) Color {
    return fromVec(toVec(c) / vecFromScalar(255));
}

pub fn fromHex(hex: []const u8) !Color {
    if (hex.len != 8 and hex.len != 6) {
        if (@inComptime()) {
            @compileError("Color hex code must be 8 characters long");
        } else {
            return Error.HexMustBe6or8CharsLong;
        }
    }

    var buf: [4]u8 = undefined;
    buf[3] = 255; // default alpha to 1
    _ = try std.fmt.hexToBytes(&buf, hex);
    return fromU8x4(@bitCast(buf));
}

// Tests

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
    try isEq(color, fromVec(f32x4{ 0, 0, 0, 1 }));
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
    const byteColor = u8x4{ 255, 0, 0, 255 };
    const color = fromU8x4(byteColor);
    try isEq(red, color);
}

test "Color to ByteColor" {
    const byteColor = toU8x4(red);
    try isEq(byteColor, u8x4{ 255, 0, 0, 255 });
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
    try testing.expectError(Error.HexMustBe6or8CharsLong, fromHex("ff00"));
}

test "hex 6 sized" {
    const hex = fromHex("00FF00");
    try isEq(hex, green);
}
