const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");

const _engine = @import("engine.zig");
const Engine = _engine.Engine;
const Mesh = _engine.Mesh;
const Shader = _engine.Shader;
const Vertex = _engine.Vertex;

const math = @import("mach").math;

const Shapes = @import("shapes.zig");

pub fn main() !void {
    var engine = Engine{};
    try engine.init(.{});
    defer engine.deinit();

    // Data

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Cube

    var mesh2 = Mesh.init(alloc);

    // try mesh2.vertices.appendSlice(&.{
    //     // front
    //     Vertex{ .position = math.vec3(-1.0, -1.0, 1.0) },
    //     Vertex{ .position = math.vec3(1.0, -1.0, 1.0) },
    //     Vertex{ .position = math.vec3(1.0, 1.0, 1.0) },
    //     Vertex{ .position = math.vec3(-1.0, 1.0, 1.0) },
    //     // back
    //     Vertex{ .position = math.vec3(-1.0, -1.0, -1.0) },
    //     Vertex{ .position = math.vec3(1.0, -1.0, -1.0) },
    //     Vertex{ .position = math.vec3(1.0, 1.0, -1.0) },
    //     Vertex{ .position = math.vec3(-1.0, 1.0, -1.0) },
    // });

    // try mesh2.indices.appendSlice(&.{
    //     // front
    //     0, 1, 2,
    //     2, 3, 0,
    //     // right
    //     1, 5, 6,
    //     6, 2, 1,
    //     // back
    //     7, 6, 5,
    //     5, 4, 7,
    //     // left
    //     4, 0, 3,
    //     3, 7, 4,
    //     // bottom
    //     4, 5, 1,
    //     1, 0, 4,
    //     // top
    //     3, 2, 6,
    //     6, 7, 3,
    // });

    try Shapes.sphere(&mesh2, 64, 32, 1);

    try mesh2.create();
    defer mesh2.deinit();

    var shader = Shader{
        .vertSource = @embedFile("vert.glsl"),
        .fragSource = @embedFile("frag.glsl"),
    };
    try shader.compile();
    defer shader.deinit();

    var motion = math.vec3(0, 0, 0);
    var camOffset = math.vec3(4, 0, 10);

    var wireframe = false;

    while (engine.isRunning()) {
        const speed = 0.001;

        if (engine.input.keyPressed(.w)) {
            camOffset.v[2] -= speed;
        } else if (engine.input.keyPressed(.s)) {
            camOffset.v[2] += speed;
        }

        if (engine.input.keyPressed(.a)) {
            camOffset.v[0] += speed;
        } else if (engine.input.keyPressed(.d)) {
            camOffset.v[0] -= speed;
        }

        if (engine.input.keyPressed(.c)) {
            engine.camera.nearPlane += 0.01;
            engine.camera.updateProjectionMatrix();
        } else if (engine.input.keyPressed(.x)) {
            engine.camera.nearPlane -= 0.01;
            engine.camera.updateProjectionMatrix();
        }

        if (engine.input.keyDown(.q)) {
            wireframe = !wireframe;

            if (wireframe) {
                gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
            } else {
                gl.polygonMode(gl.FRONT, gl.FILL);
            }
        }

        const camOffsetMatrix = math.Mat4x4.translate(camOffset);
        engine.camera.viewMatrix = math.Mat4x4.ident.mul(&camOffsetMatrix);

        //Shader.setMatrix(0, engine.camera.projectionMatrix);
        shader.bind();

        motion.v[0] = @floatCast(@sin(glfw.getTime()));
        motion.v[1] = @floatCast(@cos(glfw.getTime()));

        Shader.setUniform(0, motion);
        Shader.setUniform(1, engine.camera.projectionMatrix);
        Shader.setUniform(2, engine.camera.viewMatrix);

        mesh2.bind();
    }
}
