
const std = @import("std");
const spec = @import("../spec.zig");
const x86_64 = @import("./x86_64.zig");
const aarch64 = @import("./arm/aarch64.zig");

const builtin = @import("builtin");

const TCompileBytecode = fn (a: std.mem.Allocator, b: spec.Bytecode) anyerror ! std.ArrayList(u8);
const TMakeExecutableJITCode = fn(a: std.mem.Allocator, c: []u8) anyerror ! ExecutableJITCode;

pub const ExecutableJITCode = struct {
    code: []const u8,
};


pub const JIT = struct {
    compile_bytecode: TCompileBytecode,
    make_executable: TMakeExecutableJITCode,
    deinit: (fn(jit: ExecutableJITCode) void),
    execute: (fn(jit: ExecutableJITCode, stack: []f32) f32),
};


pub fn get_jit() JIT {
    switch (builtin.cpu.arch) {
        .x86_64 => return JIT { 
            .compile_bytecode=x86_64.compile_bytecode,
            .make_executable=x86_64.make_executable,
            .deinit=x86_64.deinit,
            .execute=x86_64.execute,
        },
        .aarch64 => return JIT {
            .compile_bytecode=aarch64.compile_bytecode,
            .make_executable=aarch64.make_executable,
            .deinit=aarch64.deinit,
            .execute=aarch64.execute,
        },
        else => @panic("Unsupported platform!")
    }
}
