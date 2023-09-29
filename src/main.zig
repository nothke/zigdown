const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const c = @import("c.zig");
const gltf = @import("zcgltf.zig");
const zgltf = @import("zgltf");

const _engine = @import("engine.zig");
const Engine = _engine.Engine;
const Mesh = _engine.Mesh;
const Shader = _engine.Shader;
const Vertex = _engine.Vertex;
const Object = _engine.Object;
const Texture = _engine.Texture;
const Material = _engine.Material;

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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var sphereMesh = Mesh.init(alloc);
    defer sphereMesh.deinit();
    try Shapes.sphere(&sphereMesh, 32, 16, 1);
    try sphereMesh.create();

    // Quad

    var quadMesh = Mesh.init(alloc);
    try Shapes.quad(&quadMesh);

    for (quadMesh.vertices.items) |*v| {
        v.position = v.position.add(&math.vec3(2, 0, 0));
    }

    try Shapes.quad(&quadMesh);

    try quadMesh.create();
    defer quadMesh.deinit();

    var shader = Shader{
        .vertSource = @embedFile("vert.glsl"),
        .fragSource = @embedFile("frag.glsl"),
    };
    try shader.compile();
    defer shader.deinit();

    var brickTex = Texture{};
    try brickTex.load("res/uv_checker.png");
    defer brickTex.deinit();
    brickTex.log();
    try brickTex.create();

    var testTex = Texture{};
    try testTex.load("res/painting.png");
    defer testTex.deinit();
    testTex.log();
    try testTex.create();

    var testMaterial = Material{ .shader = &shader };
    try testMaterial.addProp("_Color", Color.white);
    try testMaterial.addProp("_Texture", &testTex);

    var brickMaterial = Material{ .shader = &shader };
    try brickMaterial.addProp("_Color", Color.white);
    try brickMaterial.addProp("_Texture", &brickTex);

    var motion = math.vec3(0, 0, 0);
    var camOffset = math.vec3(4, 0, 10);

    var wireframe = false;

    engine.createScene();

    var sphereGO = try engine.scene.?.addObject(&sphereMesh, &testMaterial);
    var sphereGO2 = try engine.scene.?.addObject(&sphereMesh, &brickMaterial);

    var pcg = std.rand.Pcg.init(345);
    _ = pcg;

    // for (0..200) |i| {
    //     _ = i;
    //     if (pcg.random().boolean()) {
    //         _ = try engine.scene.?.addObject(&quadMesh, &testMaterial);
    //     } else {
    //         _ = try engine.scene.?.addObject(&quadMesh, &brickMaterial);
    //     }
    // }

    // GLTF

    const use_zgltf = comptime false;

    var gameMesh = Mesh.init(alloc);
    defer gameMesh.deinit();

    if (!use_zgltf) {
        var data = try gltf.parseFile(.{}, "res/testcube.gltf");
        try gltf.loadBuffers(.{}, data, "res/testcube.gltf");

        for (data.meshes.?[0..data.meshes_count]) |mesh| {
            for (mesh.primitives[0..mesh.primitives_count]) |primitive| {
                for (primitive.attributes[0..primitive.attributes_count]) |attribute| {
                    //var name = std.mem.sliceTo(attribute.name.?, 0);

                    var accessor = attribute.data;
                    const vertexCount = accessor.count;
                    try gameMesh.vertices.ensureTotalCapacity(vertexCount);

                    if (attribute.type == .position) {
                        std.log.info("Found position!", .{});

                        //accessor
                        var buffer = accessor.buffer_view.?.buffer;
                        var bufferView = accessor.buffer_view.?;
                        _ = bufferView;
                        var vertData = @as([*]const [3]f32, @ptrCast(@alignCast(buffer.data)))[0..vertexCount];

                        // const data_addr = @as([*]const u8, @ptrCast(buffer.data)) +
                        //     accessor.offset + bufferView.offset;

                        // const slice = @as([*]const [3]f32, @ptrCast(@alignCast(data_addr)))[0..vertexCount];

                        // for (slice) |vertex| {}

                        for (0..vertexCount) |vi| {
                            var vec = @Vector(3, f32){ vertData[vi][0], vertData[vi][1], vertData[vi][2] };
                            std.log.info("vec: {}", .{vec});
                            try gameMesh.vertices.append(Vertex{ .position = .{ .v = vec } });
                        }
                    }
                }

                {
                    const indexAccessor = primitive.indices.?;
                    var indexBufferView = indexAccessor.buffer_view.?;
                    var buffer = indexBufferView.buffer;
                    const indexCount = indexAccessor.count;
                    try gameMesh.indices.ensureTotalCapacity(indexCount);

                    std.log.info("index component type is: {s}, count: {}", .{ @tagName(indexAccessor.component_type), indexCount });
                    if (indexAccessor.component_type == .r_16u) {
                        std.log.info("buffer view offset: {}, size: {}, stride: {}", .{ indexBufferView.offset, indexBufferView.size, indexBufferView.stride });

                        const indexData = @as([*]const u8, @ptrCast(buffer.data)) +
                            indexAccessor.offset + indexBufferView.offset;

                        for (0..indexCount) |ic| {
                            const start = ic * 2;
                            var vi = std.mem.readIntNative(u16, indexData[start..][0..2]);
                            std.log.info("first: {}", .{vi});
                            try gameMesh.indices.append(vi);
                        }
                    }
                }
            }
        }
    } else {
        var zgltf_obj = zgltf.init(alloc);
        defer zgltf_obj.deinit();
        const gltf_source = @embedFile("../res/testcube.gltf");
        try zgltf_obj.parse(gltf_source);
        var data = zgltf_obj.data;
        zgltf_obj.debugPrint();
        var vertices = std.ArrayList(f32).init(alloc);
        defer vertices.deinit();
        for (data.meshes.items) |mesh| {
            for (mesh.primitives.items) |primitive| {
                for (primitive.attributes.items) |attribute| {
                    if (attribute == .position) {
                        const accessor = zgltf_obj.data.accessors.items[attribute.position];

                        std.log.info("Found position! comp_type={s} type={s}", .{ @tagName(accessor.component_type), @tagName(accessor.type) });
                        std.log.info("TODO - get data", .{});

                        const bvi = accessor.buffer_view.?;

                        const bi = data.buffer_views.items[bvi].buffer;
                        const buffer = data.buffers.items[bi];

                        const uri = buffer.uri.?;

                        std.log.info("first item: {}, length: {}", .{ uri.len, buffer.byte_length });

                        // TODO - get data. the following is from the example on
                        // the zgltf readme. not sure how it should work. i tried
                        // passing 'gltf_source' for the 'bin' param below, but
                        // that isn't correct.  'bin' seems to expect some kind of
                        // binary file.
                        //
                        // zgltf_obj.getDataFromBufferView(f32, &vertices, accessor, bin);

                    }
                }
            }
        }
    }

    try gameMesh.create();

    for (gameMesh.vertices.items, 0..) |v, i| {
        std.log.info("pos {}: {}", .{ i, v.position });
    }

    _ = try engine.scene.?.addObject(&gameMesh, &brickMaterial);

    var lastFrameTime = glfw.getTime();

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

        motion.v[0] = @floatCast(@sin(glfw.getTime()));
        motion.v[1] = @floatCast(@cos(glfw.getTime()));

        var modelMatrix: math.Mat4x4 = math.Mat4x4.ident.mul(&math.Mat4x4.translate(motion));

        shader.bind();
        try shader.setUniformByName("_P", engine.camera.projectionMatrix);
        try shader.setUniformByName("_V", engine.camera.viewMatrix);

        sphereGO.transform.local2world = modelMatrix;
        sphereGO2.transform.local2world = modelMatrix.mul(&math.Mat4x4.translate(math.vec3(5, 2, 0)));

        // for (engine.scene.?.objects.slice()) |*object| {
        //     const xMotion = std.math.lerp(-1, 1, pcg.random().float(f32)) * 0.1;
        //     const yMotion = std.math.lerp(-1, 1, pcg.random().float(f32)) * 0.1;
        //     const zMotion = std.math.lerp(-1, 1, pcg.random().float(f32)) * 0.1;

        //     const motionVec = math.vec3(xMotion, yMotion, zMotion);

        //     object.transform.local2world = object.transform.local2world.mul(&math.Mat4x4.translate(motionVec));
        // }

        if (engine.scene) |scene| try scene.render();
    }
}

test "color" {
    _ = Color;
}
