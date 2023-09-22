const std = @import("std");
const gl = @import("gl");
const Allocator = std.mem.Allocator;

pub const Mesh = struct {
    vertices: std.ArrayList(f32),
    indices: std.ArrayList(u32),

    vao: u32 = undefined,
    vbo: u32 = undefined,
    ibo: u32 = undefined,

    const Self = @This();

    pub fn init(allocator: Allocator) Mesh {
        return .{
            .vertices = std.ArrayList(f32).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn create(self: *Self) void {
        // VAO, VBO, IBO

        var vao: u32 = undefined;
        gl.genVertexArrays(1, &vao);

        var vbo: u32 = undefined;
        gl.genBuffers(1, &vbo);

        var ibo: u32 = undefined;
        gl.genBuffers(1, &ibo);

        gl.bindVertexArray(vao);

        gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
        gl.bufferData(gl.ARRAY_BUFFER, @intCast(self.vertices.items.len * @sizeOf(f32)), self.vertices.items[0..].ptr, gl.STATIC_DRAW);

        gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * @sizeOf(f32), null);
        gl.enableVertexAttribArray(0);

        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo);
        gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @intCast(self.indices.items.len * @sizeOf(u32)), self.indices.items[0..].ptr, gl.STATIC_DRAW);

        gl.bindBuffer(gl.ARRAY_BUFFER, 0);
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0);
        gl.bindVertexArray(0);

        self.vao = vao;
        self.vbo = vbo;
        self.ibo = ibo;
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

    pub fn compile(self: *Self) void {
        var vertShader = gl.createShader(gl.VERTEX_SHADER);
        gl.shaderSource(vertShader, 1, &self.vertSource.ptr, null);
        gl.compileShader(vertShader);

        var fragShader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(fragShader, 1, &self.fragSource.ptr, null);
        gl.compileShader(fragShader);

        self.program = gl.createProgram();
        gl.attachShader(self.program, vertShader);
        gl.attachShader(self.program, fragShader);
        gl.linkProgram(self.program);

        gl.deleteShader(vertShader);
        gl.deleteShader(fragShader);
    }

    pub fn bind(self: Self) void {
        gl.useProgram(self.program);
    }

    pub fn deinit(self: Self) void {
        gl.deleteProgram(self.program);
    }
};
