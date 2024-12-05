const std = @import("std");
const glfw = @import("mach-glfw");
const gl = @import("gl");
const c = @import("c.zig");
const cgltf = @import("zcgltf.zig");
const zgltf = @import("zgltf");

const _engine = @import("engine.zig");
const Engine = _engine.Engine;
const Mesh = _engine.Mesh;
const Shader = _engine.Shader;
const Vertex = _engine.Vertex;
const Object = _engine.Object;
const Texture = _engine.Texture;
const Material = _engine.Material;
const Model = _engine.Model;
const Primitive = _engine.Primitive;

const Color = @import("color.zig");

const math = _engine.math;

const Shapes = @import("shapes.zig");

fn flipZ(v: [3]f32) [3]f32 {
    return .{ v[0], v[1], -v[2] };
}

const AssetBlock = struct {
    allocator: std.mem.Allocator,

    meshes: std.ArrayList(Mesh),
    materials: std.ArrayList(Material),

    fn init(allocator: std.mem.Allocator) AssetBlock {
        return .{
            .allocator = allocator,
            .materials = std.ArrayList(Material).init(allocator),
            .meshes = std.ArrayList(Mesh).init(allocator),
        };
    }

    fn deinit(self: *AssetBlock) void {
        _ = self; // autofix
    }
};

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

    var gltfAssets = AssetBlock.init(alloc);
    defer gltfAssets.deinit();

    var sphereMesh = Mesh.init(alloc);
    defer sphereMesh.deinit();
    try Shapes.sphere(&sphereMesh, 32, 16, 1);
    try sphereMesh.create();

    // Quad

    var quadMesh = Mesh.init(alloc);
    try Shapes.quad(&quadMesh);

    // for (quadMesh.vertices.items) |*v| {
    //     v.position = v.position.add(&math.vec3(1, 1, 0));
    // }

    //try Shapes.quad(&quadMesh);

    try quadMesh.create();
    defer quadMesh.deinit();

    var shader = Shader{
        .vertSource = @embedFile("vert.glsl"),
        .fragSource = @embedFile("frag.glsl"),
    };
    try shader.compile();
    defer shader.deinit();

    var brickTex = try Texture.load("res/uv_checker.png");
    defer brickTex.deinit();
    brickTex.log();
    try brickTex.create();

    var testTex = try Texture.load("res/painting.png");
    defer testTex.deinit();
    testTex.log();
    try testTex.create();

    var whiteBuffer = [_]u8{255} ** 4 ** 4;
    var whiteTex = Texture{
        .buffer = &whiteBuffer,
        .height = 2,
        .width = 2,
        .channels = 4,
    };
    try whiteTex.create();

    var testMaterial = Material{ .shader = &shader };
    try testMaterial.addProp("_Color", Color.white);
    try testMaterial.addProp("_Texture", &testTex);

    var brickMaterial = Material{ .shader = &shader };
    try brickMaterial.addProp("_Color", Color.white);
    try brickMaterial.addProp("_Texture", &brickTex);

    var motion = math.vec3(0, 0, 0);
    var camOffset = math.vec3(4, 0, 10);

    var wireframe = false;

    const scene = engine.createScene();

    var sphereModel = Model.init(&sphereMesh, &testMaterial);
    var sphereModel2 = Model.init(&sphereMesh, &brickMaterial);

    var sphereGO = try scene.addObject(&sphereModel);
    var sphereGO2 = try scene.addObject(&sphereModel2);

    // {
    //     var pcg = std.Random.Pcg.init(54);

    //     for (0..200) |_| {
    //         if (pcg.random().boolean()) {
    //             _ = try scene.addObject(&quadMesh, &testMaterial);
    //         } else {
    //             _ = try scene.addObject(&quadMesh, &brickMaterial);
    //         }
    //     }
    // }

    // GLTF

    const use_zgltf = true;

    // zgltf assets, must live until the end of the app
    // TODO: move to AssetBlock
    var texturesList = std.ArrayList(Texture).init(alloc);
    defer texturesList.deinit();

    var modelList = std.ArrayList(Model).init(alloc);
    defer modelList.deinit();

    var meshList = std.ArrayList(Mesh).init(alloc);
    defer meshList.deinit();

    defer {
        for (meshList.items) |mesh| {
            mesh.deinit();
        }
    }

    var matList = std.ArrayList(Material).init(alloc);
    defer matList.deinit();

    // Old, remove
    var gameMesh = Mesh.init(alloc);
    defer gameMesh.deinit();

    if (!use_zgltf) { // Uses cgltf

        var data = try cgltf.parseFile(.{}, "res/testcube.gltf");
        try cgltf.loadBuffers(.{}, data, "res/testcube.gltf");

        // Materials

        for (data.materials.?[0..data.materials_count]) |material| {
            const view = material.pbr_metallic_roughness.base_color_texture;
            _ = view;
        }

        // Textures

        for (data.textures.?[0..data.textures_count]) |texture| {
            const image = texture.image.?;
            const view = image.buffer_view.?;
            _ = view;
        }

        // Meshes

        for (data.meshes.?[0..data.meshes_count]) |mesh| {
            for (mesh.primitives[0..mesh.primitives_count]) |primitive| {
                std.debug.assert(primitive.attributes_count > 0);

                const vertexCount = primitive.attributes[0].data.count;
                try gameMesh.vertices.ensureTotalCapacity(vertexCount);
                try gameMesh.vertices.appendNTimes(.{}, vertexCount);

                for (primitive.attributes[0..primitive.attributes_count]) |attribute| {
                    //var name = std.mem.sliceTo(attribute.name.?, 0);

                    const accessor = attribute.data;
                    const bufferView = accessor.buffer_view.?;
                    const buffer = bufferView.buffer;

                    std.log.info("-- start of attribute: {s}", .{@tagName(attribute.type)});

                    const data_addr = @as([*]const u8, @ptrCast(buffer.data)) + accessor.offset + bufferView.offset;

                    if (attribute.type == .position) {
                        const vertData = @as([*]const [3]f32, @ptrCast(@alignCast(data_addr)))[0..vertexCount];
                        for (0..vertexCount) |vi| {
                            //std.log.info("vec: {d:.2}", .{vertData[vi]});
                            gameMesh.vertices.items[vi].position = .{ .v = vertData[vi] };
                        }
                    } else if (attribute.type == .normal) {
                        const vertData = @as([*]const [3]f32, @ptrCast(@alignCast(data_addr)))[0..vertexCount];
                        for (0..vertexCount) |vi| {
                            //std.log.info("vec: {d:.2}", .{vertData[vi]});
                            gameMesh.vertices.items[vi].normal = .{ .v = vertData[vi] };
                        }
                    } else if (attribute.type == .texcoord) {
                        const vertData = @as([*]const [2]f32, @ptrCast(@alignCast(data_addr)))[0..vertexCount];
                        for (0..vertexCount) |vi| {
                            //std.log.info("vec: {d:.2}", .{vertData[vi]});
                            gameMesh.vertices.items[vi].uv = .{ .v = vertData[vi] };
                        }
                    }
                }

                {
                    const indexAccessor = primitive.indices.?;
                    const indexBufferView = indexAccessor.buffer_view.?;
                    const buffer = indexBufferView.buffer;
                    const indexCount = indexAccessor.count;
                    try gameMesh.indices.ensureTotalCapacity(indexCount);

                    std.log.info("index component type is: {s}, count: {}", .{ @tagName(indexAccessor.component_type), indexCount });
                    if (indexAccessor.component_type == .r_16u) {
                        std.log.info("buffer view offset: {}, size: {}, stride: {}", .{ indexBufferView.offset, indexBufferView.size, indexBufferView.stride });

                        const indexData = @as([*]const u8, @ptrCast(buffer.data)) +
                            indexAccessor.offset + indexBufferView.offset;

                        for (0..indexCount) |ic| {
                            const start = ic * 2;
                            //const vi = std.mem.readIntNative(u16, indexData[start..][0..2]);
                            const vi = std.mem.readInt(u16, indexData[start..][0..2], .little);
                            //std.log.info("first: {}", .{vi});
                            try gameMesh.indices.append(vi);
                        }
                    }
                }
            }
        }
    } else { // Uses zgltf
        std.log.info("###### zGLTF ######\n", .{});

        var file = try std.fs.cwd().openFile("res/testcubes.glb", .{});
        defer file.close();

        // TODO: Check the size of file and set as max bytes
        const file_buffer = try file.readToEndAllocOptions(std.heap.page_allocator, 1024 * 1024 * 4, null, 4, null);
        defer std.heap.page_allocator.free(file_buffer);

        var gltf = zgltf.init(alloc);
        defer gltf.deinit();

        try gltf.parse(file_buffer);

        //const data = zgltf_obj.data;
        gltf.debugPrint();

        for (gltf.data.images.items) |image| {
            const img = image.data.?; // will crash if glb is not used

            var tex = try Texture.loadFromBuffer(img);
            tex.log();

            try tex.create();

            try texturesList.append(tex);
        }

        // Temporary buffers, only used by gltf loader:
        var floatList = std.ArrayList(f32).init(alloc);
        defer floatList.deinit();

        var intList = std.ArrayList(u16).init(alloc);
        defer intList.deinit();

        std.log.info("", .{});
        std.log.info("# Materials", .{});

        // #MATERIAL
        for (gltf.data.materials.items) |gltfMaterial| {
            std.log.info("", .{});
            std.log.info("Material: \"{s}\"", .{gltfMaterial.name});

            var mat = Material{ .shader = &shader };

            const col = gltfMaterial.metallic_roughness.base_color_factor;
            std.log.info("   - color {d}", .{col});

            const color = Color.fromSlice(&col);
            try mat.addProp("_Color", color);

            if (gltfMaterial.metallic_roughness.base_color_texture) |tex| {
                std.log.info("   - has color texture! Index: {}", .{tex.index});
                try mat.addProp("_Texture", &texturesList.items[tex.index]); // test if has enough..?
            } else {
                try mat.addProp("_Texture", &whiteTex);
            }

            try matList.append(mat);
        }

        // #MESH
        std.log.info("", .{});
        std.log.info("# Meshes", .{});

        for (gltf.data.meshes.items) |gltfMesh| {
            std.log.info("", .{});
            std.log.info("Mesh: \"{s}\", primitives count: {}", .{ gltfMesh.name, gltfMesh.primitives.items.len });

            const model = try modelList.addOne();
            model.primitives = .{};

            for (gltfMesh.primitives.items, 0..) |primitive, pi| {
                const modelPrim = try model.primitives.addOne();

                const meshPtr = try meshList.addOne();
                meshPtr.* = Mesh.init(alloc);

                modelPrim.mesh = meshPtr;

                std.log.info("  -- primitive {}:", .{pi});

                if (primitive.material) |mi| {
                    std.log.info("    -- Material: {}", .{mi});
                    modelPrim.material = &matList.items[mi];
                } else {
                    modelPrim.material = null;
                }

                for (primitive.attributes.items) |attribute| {
                    switch (attribute) {
                        .position => |accessor_index| {
                            const accessor = gltf.data.accessors.items[accessor_index];
                            gltf.getDataFromBufferView(f32, &floatList, accessor, gltf.glb_binary.?);

                            std.debug.assert(accessor.component_type == .float);
                            std.debug.assert(accessor.type == .vec3);

                            const vertexCount: usize = @intCast(accessor.count);

                            try meshPtr.vertices.ensureTotalCapacity(vertexCount);

                            std.log.info("    -- VERTICES count: {}", .{vertexCount});

                            for (0..vertexCount) |vertexIndex| {
                                try meshPtr.vertices.append(.{ .position = math.vec3(
                                    floatList.items[vertexIndex * 3 + 0],
                                    floatList.items[vertexIndex * 3 + 1],
                                    floatList.items[vertexIndex * 3 + 2],
                                ) });
                            }
                        },
                        .normal => |accessor_index| {
                            const accessor = gltf.data.accessors.items[accessor_index];

                            std.debug.assert(accessor.component_type == .float);
                            std.debug.assert(accessor.type == .vec3);

                            gltf.getDataFromBufferView(f32, &floatList, accessor, gltf.glb_binary.?);

                            std.debug.assert(meshPtr.vertices.items.len > 0);

                            std.debug.assert(floatList.items.len == meshPtr.vertices.items.len * 3);

                            std.log.info("      -- decoding normals: type: {}, floats: {}, vertices: {}", .{ accessor.component_type, floatList.items.len, meshPtr.vertices.items.len });
                            std.debug.assert(floatList.items.len == meshPtr.vertices.items.len * 3);

                            for (meshPtr.vertices.items, 0..) |*vertex, i| {
                                vertex.normal = math.vec3(
                                    floatList.items[i * 3 + 0],
                                    floatList.items[i * 3 + 1],
                                    floatList.items[i * 3 + 2],
                                );
                            }
                        },
                        .texcoord => |accessor_index| {
                            const accessor = gltf.data.accessors.items[accessor_index];

                            std.debug.assert(accessor.component_type == .float);
                            std.debug.assert(accessor.type == .vec2);

                            gltf.getDataFromBufferView(f32, &floatList, accessor, gltf.glb_binary.?);

                            std.log.info("      -- uvs: {} == {} ?", .{ meshPtr.vertices.items.len, accessor.count });

                            std.debug.assert(meshPtr.vertices.items.len > 0);
                            std.debug.assert(floatList.items.len == meshPtr.vertices.items.len * 2);

                            for (meshPtr.vertices.items, 0..) |*vertex, i| {
                                vertex.uv = math.vec2(
                                    floatList.items[i * 2 + 0],
                                    1 - floatList.items[i * 2 + 1],
                                );
                            }
                        },
                        else => {},
                    }

                    floatList.clearRetainingCapacity();
                }

                const accessor = gltf.data.accessors.items[primitive.indices.?];
                if (accessor.component_type == .unsigned_short) {
                    intList.clearRetainingCapacity();

                    gltf.getDataFromBufferView(u16, &intList, accessor, gltf.glb_binary.?);

                    std.log.info("    -- INDICES: count: {}, triangles: {}, type: short", .{ intList.items.len, @divExact(intList.items.len, 3) });

                    for (intList.items) |vi| {
                        try meshPtr.indices.append(@intCast(vi));
                    }
                } else if (accessor.component_type == .unsigned_integer) {
                    @panic("i32 indices are not supported");
                }

                // TODO: add -freference to compile

                intList.clearRetainingCapacity();

                try meshPtr.create();
            }
        }

        // #NODES #OBJECTS
        std.log.info("", .{});
        std.log.info("# Nodes", .{});

        for (gltf.data.nodes.items) |node| {
            std.log.info("", .{});

            const obj: *Object = if (node.mesh) |mi|
                try scene.addObject(&modelList.items[mi])
            else
                try scene.addEmpty();

            if (node.matrix) |matrix| {
                std.log.info("    - Found matrix!", .{});

                obj.transform.local2world = .{
                    .v = [_]math.Vec4{
                        .{ .v = matrix[0..4].* },
                        .{ .v = matrix[4..8].* },
                        .{ .v = matrix[8..12].* },
                        .{ .v = matrix[12..16].* },
                    },
                };
            } else {
                std.log.info("\"{s}\", mesh: {}", .{ node.name, node.mesh.? });
                std.log.info("    - position: {d}", .{node.translation});
                std.log.info("    - rotation: {d}", .{node.rotation});
                std.log.info("    - scale: {d}", .{node.scale});

                // const pos: math.Vec3 = .{ .v = node.translation };
                // const scl: math.Vec3 = .{ .v = node.scale };
                // const rot: math.Quat = .{ .v = .{ .v = node.rotation } };

                // obj.transform.translate(pos);
                // obj.transform.rotate(rot);
                // obj.transform.scale(scl);

                const trs = zgltf.getGlobalTransform(&gltf.data, node);
                obj.transform.local2world = math.mat4x4(
                    &math.Vec4{ .v = trs[0] },
                    &math.Vec4{ .v = trs[1] },
                    &math.Vec4{ .v = trs[2] },
                    &math.Vec4{ .v = trs[3] },
                );

                obj.transform.local2world = obj.transform.local2world.transpose();
            }
        }
    }

    try gameMesh.create();

    //_ = try scene.addObject(&gameMesh, &brickMaterial);

    var gltfTexTestModel = Model.init(&quadMesh, &matList.items[0]);
    var gltfTexTestObject = try scene.addObject(&gltfTexTestModel);
    gltfTexTestObject.transform.local2world = math.Mat4x4.scaleScalar(2).mul(&math.Mat4x4.translate(math.vec3(1, 1, 0)));

    var lastFrameTime = glfw.getTime();

    while (engine.isRunning()) {
        const dt: f32 = @floatCast(glfw.getTime() - lastFrameTime);
        lastFrameTime = glfw.getTime();

        const speed = dt * 10;

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

        if (engine.input.keyPressed(.equal)) {
            engine.camera.fov += 0.1;
            engine.camera.updateProjectionMatrix();
        } else if (engine.input.keyPressed(.minus)) {
            engine.camera.fov -= 0.1;
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

        try scene.render();
    }
}

test "color" {
    _ = Color;
}
