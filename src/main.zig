const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const engine = @import("engine.zig");

const Mesh = engine.Mesh;
const Shader = engine.Shader;

fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
    return glfw.getProcAddress(proc);
}

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

pub fn main() !void {
    glfw.setErrorCallback(errorCallback);
    if (!glfw.init(.{})) {
        std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    }
    defer glfw.terminate();

    // Create our window
    const window = glfw.Window.create(640, 480, "Hello, mach-glfw!", null, null, .{}) orelse {
        std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
        std.process.exit(1);
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);

    const proc: glfw.GLProc = undefined;
    try gl.load(proc, glGetProcAddress);

    // Data

    const vertices = [_]f32{
        -0.5, -0.5, 0,
        0.5,  -0.5, 0,
        0,    0.5,  0,
    };

    const indices = [_]u32{
        0, 1, 2,
    };

    var mesh = Mesh{};
    @memcpy(mesh.vertices[0..vertices.len], vertices[0..]);
    mesh.vertexCount = vertices.len;

    @memcpy(mesh.indices[0..indices.len], indices[0..]);
    mesh.indexCount = indices.len;

    mesh.create();
    defer mesh.deinit();

    var shader = Shader{
        .vertSource = @embedFile("vert.glsl"),
        .fragSource = @embedFile("frag.glsl"),
    };
    shader.compile();
    defer shader.deinit();

    while (!window.shouldClose()) {
        window.swapBuffers();

        gl.clearColor(1, 0, 0, 1);
        gl.clear(gl.COLOR_BUFFER_BIT);

        shader.bind();
        mesh.bind();

        glfw.pollEvents();
    }
}
