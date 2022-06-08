const std = @import("std");
const vm = @import("./vm.zig");
const spec = @import("./spec.zig");
const utils = @import("./utils.zig");
const jit = @import("./targets/jit.zig").get_jit();


export fn ziglearning_mul(a: f32, b: f32) f32 {
    return a * b;
}

export fn ziglearning_add(a: f32, b: f32) f32 {
    return a + b + ziglearning_mul(a, b);
}

export fn ziglearning_iadd(a: i32, b: i32) i32 {
    return a + b;
}