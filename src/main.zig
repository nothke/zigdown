const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");

const _engine = @import("engine.zig");
const Engine = _engine.Engine;
const Mesh = _engine.Mesh;
const Shader = _engine.Shader;

const math = @import("mach").math;

pub fn main() !void {
    var engine = Engine{};
    try engine.init();
    defer engine.deinit();

    engine.camera.projectionMatrix = math.Mat4x4.perspective(math.degreesToRadians(f32, 90), 1, -1, 10000);
    const camOffset = math.Mat4x4.translate(math.vec3(5, 0, 10));
    engine.camera.viewMatrix = math.Mat4x4.ident.mul(&camOffset);

    // Data

    const vertices = [_]f32{
        -0.5, -0.5, 0,
        0.5,  -0.5, 0,
        0,    0.5,  0,
    };

    const indices = [_]u32{
        0, 1, 2,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var mesh = Mesh.init(alloc);

    try mesh.vertices.appendSlice(vertices[0..]);
    try mesh.indices.appendSlice(indices[0..]);

    mesh.create();
    defer mesh.deinit();

    var mesh2 = Mesh.init(alloc);

    try mesh2.vertices.appendSlice(&.{
        0, 0, 0,
        1, 0, 0,
        0, 1, 0,
        1, 1, 0,
        0, 0, 1,
        1, 0, 1,
        0, 1, 1,
        1, 1, 1,
    });

    try mesh2.indices.appendSlice(&.{
        // front
        0, 1, 2,
        2, 3, 0,
        // right
        1, 5, 6,
        6, 2, 1,
        // back
        7, 6, 5,
        5, 4, 7,
        // left
        4, 0, 3,
        3, 7, 4,
        // bottom
        4, 5, 1,
        1, 0, 4,
        // top
        3, 2, 6,
        6, 7, 3,
    });

    mesh2.create();
    defer mesh2.deinit();

    var shader = Shader{
        .vertSource = @embedFile("vert.glsl"),
        .fragSource = @embedFile("frag.glsl"),
    };
    shader.compile();
    defer shader.deinit();

    var position = math.vec3(0, 0, 0);
    _ = position;

    var motion = math.vec3(0, 0, 0);

    while (engine.isRunning()) {
        shader.bind();
        //Shader.setMatrix(0, engine.camera.projectionMatrix);
        motion.v[0] = @floatCast(@sin(glfw.getTime()));
        Shader.setVec3(0, motion);
        Shader.setMatrix(1, engine.camera.projectionMatrix);
        Shader.setMatrix(2, engine.camera.viewMatrix);

        mesh.bind();
        mesh2.bind();
    }
}
