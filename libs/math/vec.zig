const std = @import("std");

const math = @import("main.zig");
const mat = @import("mat.zig");
const quat = @import("quat.zig");

pub const VecComponent = enum { x, y, z, w };

pub fn Vec2(comptime Scalar: type) type {
    return extern struct {
        v: Vector,

        /// The vector dimension size, e.g. Vec3.n == 3
        pub const n = 2;

        /// The scalar type of this vector, e.g. Vec3.T == f32
        pub const T = Scalar;

        // The underlying @Vector type
        pub const Vector = @Vector(n, Scalar);

        const VecN = @This();

        const Shared = VecShared(Scalar, VecN);

        pub inline fn init(xs: Scalar, ys: Scalar) VecN {
            return .{ .v = .{ xs, ys } };
        }
        pub inline fn fromInt(xs: anytype, ys: anytype) VecN {
            return .{ .v = .{ @floatFromInt(xs), @floatFromInt(ys) } };
        }
        pub inline fn x(v: *const VecN) Scalar {
            return v.v[0];
        }
        pub inline fn y(v: *const VecN) Scalar {
            return v.v[1];
        }

        pub const add = Shared.add;
        pub const sub = Shared.sub;
        pub const div = Shared.div;
        pub const mul = Shared.mul;
        pub const addScalar = Shared.addScalar;
        pub const subScalar = Shared.subScalar;
        pub const divScalar = Shared.divScalar;
        pub const mulScalar = Shared.mulScalar;
        pub const less = Shared.less;
        pub const lessEq = Shared.lessEq;
        pub const greater = Shared.greater;
        pub const greaterEq = Shared.greaterEq;
        pub const splat = Shared.splat;
        pub const len2 = Shared.len2;
        pub const len = Shared.len;
        pub const normalize = Shared.normalize;
        pub const dir = Shared.dir;
        pub const dist2 = Shared.dist2;
        pub const dist = Shared.dist;
        pub const lerp = Shared.lerp;
        pub const dot = Shared.dot;
        pub const max = Shared.max;
        pub const min = Shared.min;
        pub const inverse = Shared.inverse;
        pub const negate = Shared.negate;
        pub const maxScalar = Shared.maxScalar;
        pub const minScalar = Shared.minScalar;
        pub const eqlApprox = Shared.eqlApprox;
        pub const eql = Shared.eql;
    };
}

pub fn Vec3(comptime Scalar: type) type {
    return extern struct {
        v: Vector,

        /// The vector dimension size, e.g. Vec3.n == 3
        pub const n = 3;

        /// The scalar type of this vector, e.g. Vec3.T == f32
        pub const T = Scalar;

        // The underlying @Vector type
        pub const Vector = @Vector(n, Scalar);

        const VecN = @This();

        const Shared = VecShared(Scalar, VecN);

        pub inline fn init(xs: Scalar, ys: Scalar, zs: Scalar) VecN {
            return .{ .v = .{ xs, ys, zs } };
        }
        pub inline fn fromInt(xs: anytype, ys: anytype, zs: anytype) VecN {
            return .{ .v = .{ @floatFromInt(xs), @floatFromInt(ys), @floatFromInt(zs) } };
        }
        pub inline fn x(v: *const VecN) Scalar {
            return v.v[0];
        }
        pub inline fn y(v: *const VecN) Scalar {
            return v.v[1];
        }
        pub inline fn z(v: *const VecN) Scalar {
            return v.v[2];
        }

        pub inline fn swizzle(
            v: *const VecN,
            xc: VecComponent,
            yc: VecComponent,
            zc: VecComponent,
        ) VecN {
            return .{ .v = @shuffle(VecN.T, v.v, undefined, [3]T{
                @intFromEnum(xc),
                @intFromEnum(yc),
                @intFromEnum(zc),
            }) };
        }

        /// Calculates the cross product between vector a and b.
        /// This can be done only in 3D and required inputs are Vec3.
        pub inline fn cross(a: *const VecN, b: *const VecN) VecN {
            // https://gamemath.com/book/vectors.html#cross_product
            const s1 = a.swizzle(.y, .z, .x)
                .mul(&b.swizzle(.z, .x, .y));
            const s2 = a.swizzle(.z, .x, .y)
                .mul(&b.swizzle(.y, .z, .x));
            return s1.sub(&s2);
        }

        /// Vector * Matrix multiplication
        pub inline fn mulMat(vector: *const VecN, matrix: *const mat.Mat3x3(T)) VecN {
            var result = [_]VecN.T{0} ** 3;
            inline for (0..3) |i| {
                inline for (0..3) |j| {
                    result[i] += vector.v[j] * matrix.v[i].v[j];
                }
            }
            return .{ .v = result };
        }

        /// Vector * Quat multiplication
        /// https://github.com/greggman/wgpu-matrix/blob/main/src/vec3-impl.ts#L718
        pub inline fn mulQuat(v: *const VecN, q: *const quat.Quat(Scalar)) VecN {
            const qx = q.v.x();
            const qy = q.v.y();
            const qz = q.v.z();
            const w2 = q.v.w() * 2;

            const vx = v.x();
            const vy = v.y();
            const vz = v.z();

            const uv_x = qy * vz - qz * vy;
            const uv_y = qz * vx - qx * vz;
            const uv_z = qx * vy - qy * vx;

            return math.vec3(
                vx + uv_x * w2 + (qy * uv_z - qz * uv_y) * 2,
                vy + uv_y * w2 + (qz * uv_x - qx * uv_z) * 2,
                vz + uv_z * w2 + (qz * uv_y - qy * uv_x) * 2,
            );
        }

        pub const add = Shared.add;
        pub const sub = Shared.sub;
        pub const div = Shared.div;
        pub const mul = Shared.mul;
        pub const addScalar = Shared.addScalar;
        pub const subScalar = Shared.subScalar;
        pub const divScalar = Shared.divScalar;
        pub const mulScalar = Shared.mulScalar;
        pub const less = Shared.less;
        pub const lessEq = Shared.lessEq;
        pub const greater = Shared.greater;
        pub const greaterEq = Shared.greaterEq;
        pub const splat = Shared.splat;
        pub const len2 = Shared.len2;
        pub const len = Shared.len;
        pub const normalize = Shared.normalize;
        pub const dir = Shared.dir;
        pub const dist2 = Shared.dist2;
        pub const dist = Shared.dist;
        pub const lerp = Shared.lerp;
        pub const dot = Shared.dot;
        pub const max = Shared.max;
        pub const min = Shared.min;
        pub const inverse = Shared.inverse;
        pub const negate = Shared.negate;
        pub const maxScalar = Shared.maxScalar;
        pub const minScalar = Shared.minScalar;
        pub const eqlApprox = Shared.eqlApprox;
        pub const eql = Shared.eql;
    };
}

pub fn Vec4(comptime Scalar: type) type {
    return extern struct {
        v: Vector,

        /// The vector dimension size, e.g. Vec3.n == 3
        pub const n = 4;

        /// The scalar type of this vector, e.g. Vec3.T == f32
        pub const T = Scalar;

        // The underlying @Vector type
        pub const Vector = @Vector(n, Scalar);

        const VecN = @This();

        const Shared = VecShared(Scalar, VecN);

        pub inline fn init(xs: Scalar, ys: Scalar, zs: Scalar, ws: Scalar) VecN {
            return .{ .v = .{ xs, ys, zs, ws } };
        }
        pub inline fn fromInt(xs: anytype, ys: anytype, zs: anytype, ws: anytype) VecN {
            return .{ .v = .{ @floatFromInt(xs), @floatFromInt(ys), @floatFromInt(zs), @floatFromInt(ws) } };
        }
        pub inline fn x(v: *const VecN) Scalar {
            return v.v[0];
        }
        pub inline fn y(v: *const VecN) Scalar {
            return v.v[1];
        }
        pub inline fn z(v: *const VecN) Scalar {
            return v.v[2];
        }
        pub inline fn w(v: *const VecN) Scalar {
            return v.v[3];
        }

        /// Vector * Matrix multiplication
        pub inline fn mulMat(vector: *const VecN, matrix: *const mat.Mat4x4(T)) VecN {
            var result = [_]VecN.T{0} ** 4;
            inline for (0..4) |i| {
                inline for (0..4) |j| {
                    result[i] += vector.v[j] * matrix.v[i].v[j];
                }
            }
            return .{ .v = result };
        }

        pub const add = Shared.add;
        pub const sub = Shared.sub;
        pub const div = Shared.div;
        pub const mul = Shared.mul;
        pub const addScalar = Shared.addScalar;
        pub const subScalar = Shared.subScalar;
        pub const divScalar = Shared.divScalar;
        pub const mulScalar = Shared.mulScalar;
        pub const less = Shared.less;
        pub const lessEq = Shared.lessEq;
        pub const greater = Shared.greater;
        pub const greaterEq = Shared.greaterEq;
        pub const splat = Shared.splat;
        pub const len2 = Shared.len2;
        pub const len = Shared.len;
        pub const normalize = Shared.normalize;
        pub const dir = Shared.dir;
        pub const dist2 = Shared.dist2;
        pub const dist = Shared.dist;
        pub const lerp = Shared.lerp;
        pub const dot = Shared.dot;
        pub const max = Shared.max;
        pub const min = Shared.min;
        pub const inverse = Shared.inverse;
        pub const negate = Shared.negate;
        pub const maxScalar = Shared.maxScalar;
        pub const minScalar = Shared.minScalar;
        pub const eqlApprox = Shared.eqlApprox;
        pub const eql = Shared.eql;
    };
}

pub fn VecShared(comptime Scalar: type, comptime VecN: type) type {
    return struct {
        /// Element-wise addition
        pub inline fn add(a: *const VecN, b: *const VecN) VecN {
            return .{ .v = a.v + b.v };
        }

        /// Element-wise subtraction
        pub inline fn sub(a: *const VecN, b: *const VecN) VecN {
            return .{ .v = a.v - b.v };
        }

        /// Element-wise division
        pub inline fn div(a: *const VecN, b: *const VecN) VecN {
            return .{ .v = a.v / b.v };
        }

        /// Element-wise multiplication.
        ///
        /// See also .cross()
        pub inline fn mul(a: *const VecN, b: *const VecN) VecN {
            return .{ .v = a.v * b.v };
        }

        /// Scalar addition
        pub inline fn addScalar(a: *const VecN, s: Scalar) VecN {
            return .{ .v = a.v + VecN.splat(s).v };
        }

        /// Scalar subtraction
        pub inline fn subScalar(a: *const VecN, s: Scalar) VecN {
            return .{ .v = a.v - VecN.splat(s).v };
        }

        /// Scalar division
        pub inline fn divScalar(a: *const VecN, s: Scalar) VecN {
            return .{ .v = a.v / VecN.splat(s).v };
        }

        /// Scalar multiplication.
        ///
        /// See .dot() for the dot product
        pub inline fn mulScalar(a: *const VecN, s: Scalar) VecN {
            return .{ .v = a.v * VecN.splat(s).v };
        }

        /// Element-wise a < b
        pub inline fn less(a: *const VecN, b: Scalar) bool {
            return a.v < b.v;
        }

        /// Element-wise a <= b
        pub inline fn lessEq(a: *const VecN, b: Scalar) bool {
            return a.v <= b.v;
        }

        /// Element-wise a > b
        pub inline fn greater(a: *const VecN, b: Scalar) bool {
            return a.v > b.v;
        }

        /// Element-wise a >= b
        pub inline fn greaterEq(a: *const VecN, b: Scalar) bool {
            return a.v >= b.v;
        }

        /// Returns a vector with all components set to the `scalar` value:
        ///
        /// ```
        /// var v = Vec3.splat(1337.0).v;
        /// // v.x == 1337, v.y == 1337, v.z == 1337
        /// ```
        pub inline fn splat(scalar: Scalar) VecN {
            return .{ .v = @splat(scalar) };
        }

        /// Computes the squared length of the vector. Faster than `len()`
        pub inline fn len2(v: *const VecN) Scalar {
            return switch (VecN.n) {
                inline 2 => (v.x() * v.x()) + (v.y() * v.y()),
                inline 3 => (v.x() * v.x()) + (v.y() * v.y()) + (v.z() * v.z()),
                inline 4 => (v.x() * v.x()) + (v.y() * v.y()) + (v.z() * v.z()) + (v.w() * v.w()),
                else => @compileError("Expected Vec2, Vec3, Vec4, found '" ++ @typeName(VecN) ++ "'"),
            };
        }

        /// Computes the length of the vector.
        pub inline fn len(v: *const VecN) Scalar {
            return math.sqrt(len2(v));
        }

        /// Normalizes a vector, such that all components end up in the range [0.0, 1.0].
        ///
        /// d0 is added to the divisor, which means that e.g. if you provide a near-zero value, then in
        /// situations where you would otherwise get NaN back you will instead get a near-zero vector.
        ///
        /// ```
        /// math.vec3(1.0, 2.0, 3.0).normalize(v, 0.00000001);
        /// ```
        pub inline fn normalize(v: *const VecN, d0: Scalar) VecN {
            return v.div(&VecN.splat(v.len() + d0));
        }

        /// Returns the normalized direction vector from points a and b.
        ///
        /// d0 is added to the divisor, which means that e.g. if you provide a near-zero value, then in
        /// situations where you would otherwise get NaN back you will instead get a near-zero vector.
        ///
        /// ```
        /// var v = a_point.dir(b_point, 0.0000001);
        /// ```
        pub inline fn dir(a: *const VecN, b: *const VecN, d0: Scalar) VecN {
            return b.sub(a).normalize(d0);
        }

        /// Calculates the squared distance between points a and b. Faster than `dist()`.
        pub inline fn dist2(a: *const VecN, b: *const VecN) Scalar {
            return b.sub(a).len2();
        }

        /// Calculates the distance between points a and b.
        pub inline fn dist(a: *const VecN, b: *const VecN) Scalar {
            return math.sqrt(a.dist2(b));
        }

        /// Performs linear interpolation between a and b by some amount.
        ///
        /// ```
        /// a.lerp(b, 0.0) == a
        /// a.lerp(b, 1.0) == b
        /// ```
        pub inline fn lerp(a: *const VecN, b: *const VecN, amount: Scalar) VecN {
            return a.mulScalar(1.0 - amount).add(&b.mulScalar(amount));
        }

        /// Calculates the dot product between vector a and b and returns scalar.
        pub inline fn dot(a: *const VecN, b: *const VecN) Scalar {
            return @reduce(.Add, a.v * b.v);
        }

        // Returns a new vector with the max values of two vectors
        pub inline fn max(a: *const VecN, b: *const VecN) VecN {
            return switch (VecN.n) {
                inline 2 => VecN.init(
                    @max(a.x(), b.x()),
                    @max(a.y(), b.y()),
                ),
                inline 3 => VecN.init(
                    @max(a.x(), b.x()),
                    @max(a.y(), b.y()),
                    @max(a.z(), b.z()),
                ),
                inline 4 => VecN.init(
                    @max(a.x(), b.x()),
                    @max(a.y(), b.y()),
                    @max(a.z(), b.z()),
                    @max(a.w(), b.w()),
                ),
                else => @compileError("Expected Vec2, Vec3, Vec4, found '" ++ @typeName(VecN) ++ "'"),
            };
        }

        // Returns a new vector with the min values of two vectors
        pub inline fn min(a: *const VecN, b: *const VecN) VecN {
            return switch (VecN.n) {
                inline 2 => VecN.init(
                    @min(a.x(), b.x()),
                    @min(a.y(), b.y()),
                ),
                inline 3 => VecN.init(
                    @min(a.x(), b.x()),
                    @min(a.y(), b.y()),
                    @min(a.z(), b.z()),
                ),
                inline 4 => VecN.init(
                    @min(a.x(), b.x()),
                    @min(a.y(), b.y()),
                    @min(a.z(), b.z()),
                    @min(a.w(), b.w()),
                ),
                else => @compileError("Expected Vec2, Vec3, Vec4, found '" ++ @typeName(VecN) ++ "'"),
            };
        }

        // Returns the inverse of a given vector
        pub inline fn inverse(a: *const VecN) VecN {
            return switch (VecN.n) {
                inline 2 => .{ .v = (math.vec2(1, 1).v / a.v) },
                inline 3 => .{ .v = (math.vec3(1, 1, 1).v / a.v) },
                inline 4 => .{ .v = (math.vec4(1, 1, 1, 1).v / a.v) },
                else => @compileError("Expected Vec2, Vec3, Vec4, found '" ++ @typeName(VecN) ++ "'"),
            };
        }

        // Negates a given vector
        pub inline fn negate(a: *const VecN) VecN {
            return switch (VecN.n) {
                inline 2 => .{ .v = math.vec2(-1, -1).v * a.v },
                inline 3 => .{ .v = math.vec3(-1, -1, -1).v * a.v },
                inline 4 => .{ .v = math.vec4(-1, -1, -1, -1).v * a.v },
                else => @compileError("Expected Vec2, Vec3, Vec4, found '" ++ @typeName(VecN) ++ "'"),
            };
        }

        // Returns the largest scalar of two vectors
        pub inline fn maxScalar(a: *const VecN, b: *const VecN) Scalar {
            var max_scalar: Scalar = a.v[0];
            inline for (0..VecN.n) |i| {
                if (a.v[i] > max_scalar)
                    max_scalar = a.v[i];
                if (b.v[i] > max_scalar)
                    max_scalar = b.v[i];
            }

            return max_scalar;
        }

        // Returns the smallest scalar of two vectors
        pub inline fn minScalar(a: *const VecN, b: *const VecN) Scalar {
            var min_scalar: Scalar = a.v[0];
            inline for (0..VecN.n) |i| {
                if (a.v[i] < min_scalar)
                    min_scalar = a.v[i];
                if (b.v[i] < min_scalar)
                    min_scalar = b.v[i];
            }

            return min_scalar;
        }

        /// Checks for approximate (absolute tolerance) equality between two vectors
        /// of the same type and dimensions
        pub inline fn eqlApprox(a: *const VecN, b: *const VecN, tolerance: Scalar) bool {
            var i: usize = 0;
            while (i < VecN.n) : (i += 1) {
                if (!math.eql(Scalar, a.v[i], b.v[i], tolerance)) {
                    return false;
                }
            }
            return true;
        }

        /// Checks for approximate (absolute epsilon tolerance) equality
        /// between two vectors of the same type and dimensions
        pub inline fn eql(a: *const VecN, b: *const VecN) bool {
            return a.eqlApprox(b, math.eps(Scalar));
        }
    };
}
