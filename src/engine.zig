const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");
const math = @import("mach").math;
const c = @import("c.zig");
const Color = @import("color.zig").Color;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const Mat4x4 = math.Mat4x4;

const ident = Mat4x4.ident;
const v2zero = math.vec2(0, 0);
const v3zero = math.vec3(0, 0, 0);
const v4zero = math.vec4(0, 0, 0, 0);

var instance: *Engine = undefined;

pub const WindowProps = struct {
    width: u32 = 800,
    height: u32 = 600,
    fullscreen: bool = true,
    title: [:0]const u8 = "zigdown!",
    vsync: bool = true,
};

pub const Engine = struct {
    window: ?glfw.Window = null,
    camera: Camera = .{},
    input: Input = .{},

    scene: ?Scene = null,

    const Error = error{
        GLError,
    };

    const Self = @This();

    fn glGetProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
        _ = p;
        return glfw.getProcAddress(proc);
    }

    /// Default GLFW error handling callback
    fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
        std.log.err("glfw: {}: {s}\n", .{ error_code, description });
    }

    pub fn init(self: *Self, windowProps: WindowProps) !void {
        instance = self;

        glfw.setErrorCallback(errorCallback);
        if (!glfw.init(.{})) {
            std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
            std.process.exit(1);
        }

        var monitor = glfw.Monitor.getPrimary().?;
        const mode = monitor.getVideoMode().?;

        const width = if (windowProps.fullscreen) mode.getWidth() else windowProps.width;
        const height = if (windowProps.fullscreen) mode.getHeight() else windowProps.height;

        const hints = if (windowProps.fullscreen) glfw.Window.Hints{
            .red_bits = @intCast(mode.getRedBits()),
            .green_bits = @intCast(mode.getGreenBits()),
            .blue_bits = @intCast(mode.getBlueBits()),
            .refresh_rate = @intCast(mode.getRefreshRate()),
        } else glfw.Window.Hints{};

        // Create our window
        self.window = glfw.Window.create(
            width,
            height,
            windowProps.title,
            if (windowProps.fullscreen) monitor else null,
            null,
            hints,
        ) orelse {
            std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
            std.process.exit(1);
        };

        glfw.makeContextCurrent(self.window);

        const proc: glfw.GLProc = undefined;
        try gl.load(proc, glGetProcAddress);

        self.camera.engine = self;
        self.camera.updateProjectionMatrix();

        self.input.engine = self;
        self.input.keyEvents = try std.BoundedArray(Input.Event, 16).init(0);

        self.window.?.setKeyCallback(Input.keyCallback);

        glfw.swapInterval(if (windowProps.vsync) 1 else 0);

        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.CULL_FACE);
    }

    pub fn deinit(self: Self) void {
        if (self.window) |window| {
            window.destroy();
        }

        glfw.terminate();
    }

    pub fn createScene(self: *Self) void {
        self.scene = Scene{
            .objects = .{},
        };
    }

    fn toFloat01(byte: u8) f32 {
        return @as(f32, @floatFromInt(byte)) / 255;
    }

    pub fn isRunning(self: *Self) bool {
        self.window.?.swapBuffers();

        self.input.clearEvents();
        glfw.pollEvents();

        gl.clearColor(toFloat01(212), toFloat01(25), toFloat01(125), 1);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        return !self.window.?.shouldClose();
    }

    pub const Input = struct {
        engine: *Engine = undefined,
        keyEvents: std.BoundedArray(Event, 16) = undefined,

        const Event = struct {
            key: glfw.Key,
            scancode: i32,
            action: glfw.Action,
            mods: glfw.Mods,
        };

        pub fn keyCallback(window: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
            _ = window;
            instance.input.keyEvents.append(Event{
                .key = key,
                .scancode = scancode,
                .action = action,
                .mods = mods,
            }) catch {};

            std.log.info("key: {}, pressed: {}, action: {}, allocd keys: {}", .{ key, scancode, action, instance.input.keyEvents.len });
        }

        pub fn clearEvents(self: *Input) void {
            self.keyEvents.len = 0;
        }

        pub fn keyPressed(self: Input, key: glfw.Key) bool {
            return self.engine.window.?.getKey(key) == glfw.Action.press;
        }

        fn keyAction(self: Input, key: glfw.Key, action: glfw.Action) bool {
            for (self.keyEvents.constSlice()) |event| {
                return event.key == key and event.action == action;
            }

            return false;
        }

        pub fn keyDown(self: Input, key: glfw.Key) bool {
            return self.keyAction(key, glfw.Action.press);
        }

        pub fn keyUp(self: Input, key: glfw.Key) bool {
            return self.keyAction(key, glfw.Action.release);
        }

        pub fn keyRepeat(self: Input, key: glfw.Key) bool {
            return self.keyAction(key, glfw.Action.repeat);
        }
    };

    pub fn setWireframe(enable: bool) void {
        if (enable) {
            gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
        } else {
            gl.polygonMode(gl.FRONT, gl.FILL);
        }
    }
};

pub const Camera = struct {
    projectionMatrix: Mat4x4 = ident,
    viewMatrix: Mat4x4 = ident,

    nearPlane: f32 = -1,
    farPlane: f32 = 1,
    fov: f32 = 75,
    aspectRatio: f32 = 1,

    engine: *Engine = undefined,

    pub fn updateProjectionMatrix(self: *Camera) void {
        const size = self.engine.window.?.getSize();
        self.aspectRatio = @as(f32, @floatFromInt(size.width)) / @as(f32, @floatFromInt(size.height));

        self.projectionMatrix = Mat4x4.perspective(
            math.degreesToRadians(f32, self.fov),
            self.aspectRatio,
            self.nearPlane,
            self.farPlane,
        );
    }
};

pub const Transform = struct {
    local2world: Mat4x4 = ident,
};

pub const Object = struct {
    mesh: ?*Mesh = null,
    material: ?*Material = null,
    transform: Transform = .{},

    pub fn render(self: Object) !void {
        const meshPtr = self.mesh orelse return;
        const materialPtr = self.material orelse return;

        try materialPtr.bind();
        try materialPtr.shader.?.setUniformByName("_M", self.transform.local2world);
        meshPtr.bind();
    }
};

pub const Scene = struct {
    objects: std.BoundedArray(Object, 1024),

    pub fn addObject(self: *Scene, mesh: *Mesh, material: *Material) !*Object {
        const object = try self.objects.addOne();
        object.* = .{ .mesh = mesh, .material = material };
        return object;
    }

    pub fn render(self: Scene) !void {
        for (self.objects.constSlice()) |object| {
            try object.render();
        }
    }
};

pub const Vertex = extern struct {
    position: Vec3 = v3zero,
    uv: Vec2 = v2zero,
    normal: Vec3 = v3zero,
    color: Vec4 = v4zero,

    fn addAttributes() void {
        Mesh.addElement(0, false, 3, 0); // position
        Mesh.addElement(1, false, 2, @offsetOf(Vertex, "uv")); // uvs
        Mesh.addElement(2, false, 3, @offsetOf(Vertex, "normal")); // normals
        Mesh.addElement(3, false, 4, @offsetOf(Vertex, "color")); // colors
    }

    fn logOffset(comptime name: []const u8) void {
        std.log.info("offset of {s}: {}", .{ name, @offsetOf(Vertex, name) });
    }
};

pub const Mesh = struct {
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),

    vao: u32 = undefined,
    vbo: u32 = undefined,
    ibo: u32 = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Mesh {
        return .{
            .vertices = std.ArrayList(Vertex).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
        };
    }

    fn addElement(attributeId: u32, normalize: bool, elementCount: u32, elementPosition: u32) void {
        const norm: u8 = if (normalize) gl.TRUE else gl.FALSE;

        const ec: ?*const anyopaque = @ptrFromInt(elementPosition);
        gl.vertexAttribPointer(attributeId, @intCast(elementCount), gl.FLOAT, norm, @sizeOf(Vertex), ec);
        gl.enableVertexAttribArray(attributeId);
    }

    pub fn create(self: *Self) !void {
        // VAO, VBO, IBO

        var vao: u32 = undefined;
        gl.genVertexArrays(1, &vao);

        var vbo: u32 = undefined;
        gl.genBuffers(1, &vbo);

        var ibo: u32 = undefined;
        gl.genBuffers(1, &ibo);

        gl.bindVertexArray(vao);

        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(self.vertices.items.len * @sizeOf(Vertex)), self.vertices.items[0..].ptr, gl.STATIC_DRAW);

        Vertex.addAttributes();

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(self.indices.items.len * @sizeOf(u32)), self.indices.items[0..].ptr, gl.STATIC_DRAW);

        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
        gl.bindVertexArray(0);

        std.log.info("sizeof vertex: {}", .{@sizeOf(Vertex)});

        self.vao = vao;
        self.vbo = vbo;
        self.ibo = ibo;

        try glLogError();
    }

    pub fn bind(self: Self) void {
        gl.bindVertexArray(self.vao);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, self.ibo);
        gl.drawElements(gl.TRIANGLES, @intCast(self.indices.items.len), gl.UNSIGNED_INT, null);
    }

    pub fn deinit(self: Self) void {
        gl.deleteVertexArrays(1, &self.vao);
        gl.deleteBuffers(1, &self.vbo);
        gl.deleteBuffers(1, &self.ibo);

        self.indices.deinit();
        self.vertices.deinit();
    }
};

pub const Shader = struct {
    program: u32 = 0,
    vertSource: []const u8,
    fragSource: []const u8,

    const Self = @This();

    const Error = error{
        InvalidUniformName,
        AttemptingToSetUniformButProgramIsNotBound,
        ShaderCompilationFailed,
        ShaderLinkingFailed,
        GLError,
    };

    pub fn compile(self: *Self) !void {
        const vertShader = gl.createShader(gl.VERTEX_SHADER);
        gl.shaderSource(vertShader, 1, &self.vertSource.ptr, null);
        gl.compileShader(vertShader);
        try logShaderError(vertShader);

        const fragShader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(fragShader, 1, &self.fragSource.ptr, null);
        gl.compileShader(fragShader);
        try logShaderError(fragShader);

        self.program = gl.createProgram();
        gl.attachShader(self.program, vertShader);
        gl.attachShader(self.program, fragShader);
        gl.linkProgram(self.program);

        try glLogError();

        {
            var isLinked: i32 = 0;
            gl.getProgramiv(self.program, gl.LINK_STATUS, &isLinked);
            if (isLinked == gl.FALSE) {
                var maxLength: i32 = undefined;
                gl.getProgramiv(self.program, gl.INFO_LOG_LENGTH, &maxLength);
                var buffer = [1:0]u8{0} ** 256;
                gl.getProgramInfoLog(self.program, maxLength, &maxLength, &buffer);

                gl.deleteProgram(self.program);
                self.program = 0;

                return Error.ShaderLinkingFailed;
            }
        }

        gl.deleteShader(vertShader);
        gl.deleteShader(fragShader);
    }

    fn checkIfProgramIsBound() bool {
        var program: i32 = undefined;
        gl.getIntegerv(gl.CURRENT_PROGRAM, &program);
        return program > 0;
    }

    pub fn bind(self: Self) void {
        gl.useProgram(self.program);
    }

    pub fn deinit(self: Self) void {
        gl.deleteProgram(self.program);
    }

    pub fn setUniform(location: i32, value: anytype) !void {
        if (!checkIfProgramIsBound()) {
            return Error.AttemptingToSetUniformButProgramIsNotBound;
        }

        const T = @TypeOf(value);

        switch (T) {
            i32 => gl.uniform1i(location, value),
            f32 => gl.uniform1f(location, value),
            Vec2 => gl.uniform2fv(location, 1, &value.v[0]),
            Vec3 => gl.uniform3fv(location, 1, &value.v[0]),
            Vec4 => gl.uniform4fv(location, 1, &value.v[0]),
            Mat4x4 => gl.uniformMatrix4fv(location, 1, gl.FALSE, &value.v[0].v[0]),
            else => @compileError("Uniform with type of " ++ @typeName(T) ++ " is not supported"),
        }
    }

    pub fn setUniformByName(self: Self, name: [:0]const u8, value: anytype) !void {
        const location = gl.getUniformLocation(self.program, name);

        if (location < 0) {
            std.log.err("Uniform by name of {s} doesn't exist", .{name});
            return Error.InvalidUniformName;
        }

        try setUniform(location, value);

        glLogError() catch |err| {
            std.log.err("Attempting to set uniform '{s}' at location {} with value of type: {}", .{ name, location, @TypeOf(value) });
            return err;
        };
    }

    fn logShaderError(shader: u32) !void {
        var isCompiled: i32 = 0;
        gl.getShaderiv(shader, gl.COMPILE_STATUS, &isCompiled);

        if (isCompiled == gl.FALSE) {
            var maxLength: i32 = 0;
            gl.getShaderiv(shader, gl.INFO_LOG_LENGTH, &maxLength);

            const errorLogSize: usize = 512;
            var errorLog = [1:0]u8{0} ** errorLogSize;
            gl.getShaderInfoLog(shader, errorLogSize, &maxLength, &errorLog);

            gl.deleteShader(shader);

            std.log.err("\nShader compilation failed:\n{s}", .{errorLog[0..@intCast(maxLength)]});

            return Error.ShaderCompilationFailed;
        }
    }
};

pub const Material = struct {
    shader: ?*Shader = null,
    props: std.BoundedArray(Property, 16) = .{},

    pub const Property = struct {
        name: [:0]const u8,
        data: Data,

        const Data = union(enum) {
            int: i32,
            float: f32,
            texture: *Texture,
            vec2: Vec3,
            vec3: Vec3,
            vec4: Vec4,
            mat4: Mat4x4,
            color: Color,
        };
    };

    pub fn bind(self: Material) !void {
        if (self.shader) |shader| {
            shader.bind();

            var textureUnit: i32 = 0;

            for (self.props.constSlice()) |prop| {
                switch (prop.data) {
                    .texture => |texture| {
                        try texture.bind(textureUnit);
                        try shader.setUniformByName(prop.name, textureUnit);
                        textureUnit += 1;
                    },
                    .color => |color| try shader.setUniformByName(prop.name, color.toVec4()),
                    inline else => |data| try shader.setUniformByName(prop.name, data),
                }

                try glLogError();
            }
        }
    }

    pub fn addProp(self: *Material, name: [:0]const u8, value: anytype) !void {
        const T = @TypeOf(value);

        // sets union field deduced from type of value
        inline for (std.meta.fields(Property.Data)) |field| {
            if (field.type == T) {
                try self.props.append(Property{
                    .name = name,
                    .data = @unionInit(Property.Data, field.name, value),
                });

                return;
            }
        }

        @compileError(@typeName(T) ++ " is an unsupported property type");
    }
};

pub const Texture = struct {
    width: i32 = 0,
    height: i32 = 0,
    channels: i32 = 0,
    buffer: [*c]u8 = null,
    id: u32 = 0,

    const Error = error{
        InvalidPath,
        FailedLoading,
    };

    pub fn load(self: *Texture, path: [:0]const u8) !void {
        var w: c_int = undefined;
        var h: c_int = undefined;
        var channels: c_int = undefined;

        c.stbi_set_flip_vertically_on_load(1);
        const buffer = c.stbi_load(path, &w, &h, &channels, 0);

        if (buffer == null) {
            return Error.FailedLoading;
        }

        self.width = w;
        self.height = h;
        self.channels = channels;
        self.buffer = buffer;
    }

    pub fn create(self: *Texture) !void {
        gl.genTextures(1, &self.id);
        gl.bindTexture(gl.TEXTURE_2D, self.id);
        try glLogError();

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        try glLogError();

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        try glLogError();

        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            self.width,
            self.height,
            0,
            gl.RGB,
            gl.UNSIGNED_BYTE,
            self.buffer,
        );
        try glLogError();
    }

    pub fn bind(self: Texture, slot: i32) !void {
        glClearError();
        gl.activeTexture(gl.TEXTURE0 + @as(c_uint, @intCast(slot)));
        try glLogError();
        gl.bindTexture(gl.TEXTURE_2D, self.id);
        try glLogError();
    }

    pub fn deinit(self: Texture) void {
        if (self.buffer != null)
            c.stbi_image_free(self.buffer);
    }

    pub fn log(self: Texture) void {
        std.log.info("width: {}, height: {}, channels: {}, isValid {}", .{ self.width, self.height, self.channels, self.buffer != null });
    }
};

pub fn glLogError() !void {
    var err: gl.GLenum = gl.getError();
    const hasErrored = err != gl.NO_ERROR;
    while (err != gl.NO_ERROR) {
        const errorString = switch (err) {
            gl.INVALID_ENUM => "INVALID_ENUM",
            gl.INVALID_VALUE => "INVALID_VALUE",
            gl.INVALID_OPERATION => "INVALID_OPERATION",
            gl.OUT_OF_MEMORY => "OUT_OF_MEMORY",
            gl.INVALID_FRAMEBUFFER_OPERATION => "INVALID_FRAMEBUFFER_OPERATION",
            else => "unknown error",
        };

        // GL_STACK_OVERFLOW and GL_STACK_UNDEFLOW don't exist??

        std.log.err("Found OpenGL error: {s}", .{errorString});

        err = gl.getError();
    }

    if (hasErrored)
        return Engine.Error.GLError;
}

pub fn glClearError() void {
    while (gl.getError() != gl.NO_ERROR) {}
}
