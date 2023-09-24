const std = @import("std");
const gl = @import("gl");
const glfw = @import("mach-glfw");
const math = @import("mach").math;

pub const WindowProps = struct {
    width: u32 = 800,
    height: u32 = 600,
    title: [:0]const u8 = "zigdown!",
    vsync: bool = true,
};

pub const Engine = struct {
    window: ?glfw.Window = null,
    camera: Camera = .{},

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
        glfw.setErrorCallback(errorCallback);
        if (!glfw.init(.{})) {
            std.log.err("failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
            std.process.exit(1);
        }

        // Create our window
        self.window = glfw.Window.create(windowProps.width, windowProps.height, windowProps.title, null, null, .{}) orelse {
            std.log.err("failed to create GLFW window: {?s}", .{glfw.getErrorString()});
            std.process.exit(1);
        };

        glfw.makeContextCurrent(self.window);

        const proc: glfw.GLProc = undefined;
        try gl.load(proc, glGetProcAddress);

        self.camera.engine = self;
        self.camera.updateProjectionMatrix();

        gl.enable(gl.DEPTH_TEST);
        gl.enable(gl.CULL_FACE);
    }

    pub fn deinit(self: Self) void {
        if (self.window) |window| {
            window.destroy();
        }

        glfw.terminate();
    }

    fn toFloat01(byte: u8) f32 {
        return @as(f32, @floatFromInt(byte)) / 255;
    }

    pub fn isRunning(self: Self) bool {
        self.window.?.swapBuffers();

        glfw.pollEvents();

        gl.clearColor(toFloat01(212), toFloat01(25), toFloat01(125), 1);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        return !self.window.?.shouldClose();
    }

    pub fn keyPressed(self: Self, key: glfw.Key) bool {
        return self.window.?.getKey(key) == glfw.Action.press;
    }
};

pub const Camera = struct {
    projectionMatrix: math.Mat4x4 = math.Mat4x4.ident,
    viewMatrix: math.Mat4x4 = math.Mat4x4.ident,

    nearPlane: f32 = -1 + 0.1,
    farPlane: f32 = 1000,
    fov: f32 = 75,
    aspectRatio: f32 = 1,

    engine: *Engine = undefined,

    pub fn updateProjectionMatrix(self: *Camera) void {
        const size = self.engine.window.?.getSize();
        self.aspectRatio = @as(f32, @floatFromInt(size.width)) / @as(f32, @floatFromInt(size.height));

        self.projectionMatrix = math.Mat4x4.perspective(
            math.degreesToRadians(f32, self.fov),
            self.aspectRatio,
            self.nearPlane,
            self.farPlane,
        );
    }
};

const v2zero = math.vec2(0, 0);
const v3zero = math.vec3(0, 0, 0);
const v4zero = math.vec4(0, 0, 0, 0);

pub const Vertex = extern struct {
    position: math.Vec3 = v3zero,
    uv: math.Vec2 = v2zero,
    normal: math.Vec3 = v3zero,
    color: math.Vec4 = v4zero,

    fn addAttributes() void {
        // logOffset("position");
        // logOffset("uv");
        // logOffset("normal");
        // logOffset("color");

        //const fs = @sizeOf(f32);
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
        var norm: u8 = if (normalize) gl.TRUE else gl.FALSE;

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
        ShaderCompilationFailed,
        GLError,
    };

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

    pub fn compile(self: *Self) !void {
        var vertShader = gl.createShader(gl.VERTEX_SHADER);
        gl.shaderSource(vertShader, 1, &self.vertSource.ptr, null);
        gl.compileShader(vertShader);
        try logShaderError(vertShader);

        var fragShader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(fragShader, 1, &self.fragSource.ptr, null);
        gl.compileShader(fragShader);
        try logShaderError(fragShader);

        self.program = gl.createProgram();
        gl.attachShader(self.program, vertShader);
        gl.attachShader(self.program, fragShader);
        gl.linkProgram(self.program);

        try glLogError();

        gl.deleteShader(vertShader);
        gl.deleteShader(fragShader);
    }

    pub fn bind(self: Self) void {
        gl.useProgram(self.program);
    }

    pub fn deinit(self: Self) void {
        gl.deleteProgram(self.program);
    }

    pub fn setUniform(location: i32, value: anytype) void {
        comptime {
            const T = @TypeOf(value);

            if (T != i32 and
                T != f32 and
                T != math.Vec2 and
                T != math.Vec3 and
                T != math.Vec4 and
                T != math.Mat4x4)
            {
                @compileError("Uniform with type of " ++ @typeName(T) ++ " is not supported");
            }
        }

        switch (@TypeOf(value)) {
            inline i32 => gl.uniform1i(location, value),
            inline f32 => gl.uniform1f(location, value),
            inline math.Vec2 => gl.uniform2fv(location, 1, &value.v[0]),
            inline math.Vec3 => gl.uniform3fv(location, 1, &value.v[0]),
            inline math.Vec4 => gl.uniform4fv(location, 1, &value.v[0]),
            inline math.Mat4x4 => gl.uniformMatrix4fv(location, 1, gl.FALSE, &value.v[0].v[0]),
            inline else => unreachable,
        }
    }

    pub fn setUniformByName(self: Self, name: [:0]const u8, value: anytype) !void {
        const location = gl.getUniformLocation(self.program, name);

        if (location < 0)
            return Error.InvalidUniformName;

        setUniform(location, value);
    }
};

fn glLogError() !void {
    var err: gl.GLenum = gl.getError();
    const hasErrored = err != gl.NO_ERROR;
    while (err != gl.NO_ERROR) {
        var errorString = switch (err) {
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
