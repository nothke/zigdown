const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const c = @import("c.zig");

const _engine = @import("engine.zig");
const Engine = _engine.Engine;
const Mesh = _engine.Mesh;
const Shader = _engine.Shader;
const Vertex = _engine.Vertex;
const Object = _engine.Object;

const Color = @import("color.zig");

const math = @import("mach").math;

const Shapes = @import("shapes.zig");

pub fn main() !void {
    var engine = Engine{};
    try engine.init(.{
        .width = 800, // 1900
        .height = 600, // 1024
        .fullscreen = false,
    });
    defer engine.deinit();

    _ = c;

    // Data

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Cube

    var sphereMesh = Mesh.init(alloc);
    //try Shapes.sphere(&sphereMesh, 64, 32, 1);
    try Shapes.quad(&sphereMesh);

    try sphereMesh.create();
    defer sphereMesh.deinit();

    var shader = Shader{
        .vertSource = @embedFile("vert.glsl"),
        .fragSource = @embedFile("frag.glsl"),
    };
    try shader.compile();
    defer shader.deinit();

    var motion = math.vec3(0, 0, 0);
    var camOffset = math.vec3(4, 0, 10);

    var wireframe = false;

    engine.createScene();
    var sphereGO = try engine.scene.?.addObject(&sphereMesh, &shader);
    var sphereGO2 = try engine.scene.?.addObject(&sphereMesh, &shader);

    for (0..200) |i| {
        _ = i;
        _ = try engine.scene.?.addObject(&sphereMesh, &shader);
    }

    var pcg = std.rand.Pcg.init(345);

    var lastFrameTime = glfw.getTime();

    const color = Color.init(0, 0, 0, 0);
    _ = color;

    var w: c_int = undefined;
    var h: c_int = undefined;
    var channels: c_int = undefined;
    var buffer = c.stbi_load("res/test.png", &w, &h, &channels, 4);
    if (buffer == null) {
        std.log.err("Buffer is null", .{});
    }

    std.log.info("w: {}, h: {}", .{ w, h });
    defer c.stbi_image_free(buffer);

    var id: u32 = undefined;
    gl.genTextures(1, &id);
    gl.bindTexture(gl.TEXTURE_2D, id);

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);

    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA8, w, h, 0, gl.RGBA8, gl.UNSIGNED_BYTE, buffer);

    while (engine.isRunning()) {
        var dt: f32 = @floatCast(glfw.getTime() - lastFrameTime);
        lastFrameTime = glfw.getTime();

        const speed = dt;

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
            Engine.setWireframe(wireframe);
        }

        const camOffsetMatrix = math.Mat4x4.translate(camOffset);
        engine.camera.viewMatrix = math.Mat4x4.ident.mul(&camOffsetMatrix);

        //Shader.setMatrix(0, engine.camera.projectionMatrix);
        shader.bind();

        gl.bindTexture(gl.TEXTURE_2D, id);

        motion.v[0] = @floatCast(@sin(glfw.getTime()));
        motion.v[1] = @floatCast(@cos(glfw.getTime()));

        var modelMatrix: math.Mat4x4 = math.Mat4x4.ident.mul(&math.Mat4x4.translate(motion));

        //Shader.setUniform(0, motion);
        try shader.setUniformByName("_P", engine.camera.projectionMatrix);
        try shader.setUniformByName("_V", engine.camera.viewMatrix);
        try shader.setUniformByName("_Color", Color.chartreuse.toVec4());
        try shader.setUniformByName("_Texture", @as(i32, @intCast(id)));

        gl.bindTexture(gl.TEXTURE_2D, id);

        sphereGO.transform.local2world = modelMatrix;
        sphereGO2.transform.local2world = modelMatrix.mul(&math.Mat4x4.translate(math.vec3(5, 2, 0)));

        for (engine.scene.?.objects.slice()) |*object| {
            const xMotion = std.math.lerp(-1, 1, pcg.random().float(f32)) * 0.1;
            const yMotion = std.math.lerp(-1, 1, pcg.random().float(f32)) * 0.1;
            const zMotion = std.math.lerp(-1, 1, pcg.random().float(f32)) * 0.1;

            const motionVec = math.vec3(xMotion, yMotion, zMotion);

            object.transform.local2world = object.transform.local2world.mul(&math.Mat4x4.translate(motionVec));
        }

        if (engine.scene) |scene| {
            try scene.render();
        }
    }
}

test "color" {
    _ = Color;
}
