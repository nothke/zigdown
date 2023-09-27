const std = @import("std");

const _engine = @import("engine.zig");
const Engine = _engine.Engine;
const Mesh = _engine.Mesh;
const Shader = _engine.Shader;
const Vertex = _engine.Vertex;
const math = @import("mach").math;

fn tof32(value: anytype) f32 {
    return @as(f32, @floatFromInt(value));
}

fn circlePoints(points: []math.Vec3, sides: u32, radius: f32) !void {
    if (points.len != sides + 1)
        @panic("Points slice must be sides + 1");

    for (0..sides + 1) |i| {
        var theta = tof32(i) * 2 * math.pi / tof32(sides);
        var ci = math.vec3(@cos(theta) * radius, 0, @sin(theta) * radius);
        points[i] = ci;
    }
}

pub fn sphere(mesh: *Mesh, radialSegments: i32, verticalSegments: i32, radius: f32) !void {
    const radSegs: u32 = @intCast(if (radialSegments < 3) 3 else radialSegments);
    const vertSegs: u32 = @intCast(if (verticalSegments < 3) 3 else verticalSegments);

    const vCt: u32 = @intCast(mesh.vertices.items.len);

    for (0..(vertSegs + 1)) |v| {
        const height = -@cos(tof32(v) / tof32(vertSegs) * std.math.pi) * radius;
        const ringRadius = @sin(tof32(v) / tof32(vertSegs) * std.math.pi) * radius;

        var buffer = try std.BoundedArray(math.Vec3, 256).init(radSegs + 1);
        try circlePoints(buffer.slice(), radSegs, ringRadius);

        for (0..radSegs + 1) |i| {
            buffer.slice()[i].v[1] += height;

            const texU: f32 = tof32(i) / tof32(radSegs + 1);
            const texV: f32 = tof32(v) / tof32(vertSegs + 1);

            try mesh.vertices.append(Vertex{
                .position = buffer.slice()[i],
                .uv = math.vec2(texU, texV),
            });
        }
    }

    for (mesh.vertices.items) |*vertex| {
        vertex.normal = vertex.position.normalize(1);
    }

    for (0..radSegs) |r| {
        for (0..vertSegs) |v| {
            const v0 = vCt + ((radSegs + 1) * v) + r;
            const v1 = vCt + ((radSegs + 1) * v) + r + 1;
            const v2 = v0 + (radSegs + 1);
            const v3 = v1 + (radSegs + 1);

            try mesh.indices.append(@intCast(v0));
            try mesh.indices.append(@intCast(v1));
            try mesh.indices.append(@intCast(v2));

            try mesh.indices.append(@intCast(v1));
            try mesh.indices.append(@intCast(v3));
            try mesh.indices.append(@intCast(v2));
        }
    }
}

pub fn quad(mesh: *Mesh) !void {
    const v3 = math.vec3;
    const v2 = math.vec2;

    const i: u32 = @intCast(mesh.vertices.items.len);

    const norm = math.vec3(0, 0, -1);

    try mesh.vertices.append(.{ .position = v3(0, 0, 0), .uv = v2(0, 0), .normal = norm });
    try mesh.vertices.append(.{ .position = v3(1, 0, 0), .uv = v2(1, 0), .normal = norm });
    try mesh.vertices.append(.{ .position = v3(0, 1, 0), .uv = v2(0, 1), .normal = norm });
    try mesh.vertices.append(.{ .position = v3(1, 1, 0), .uv = v2(1, 1), .normal = norm });

    try mesh.indices.appendSlice(&.{
        i + 0, i + 1, i + 2,
        i + 1, i + 3, i + 2,
    });
}
