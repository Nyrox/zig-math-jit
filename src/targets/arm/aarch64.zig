
const spec = @import("../../spec.zig");
const std = @import("std");
const jit = @import("../jit.zig");

const Bytecode = spec.Bytecode;
const Op = spec.Op;

pub fn compile_bytecode(allocator: std.mem.Allocator, bytecode: Bytecode) anyerror ! std.ArrayList(u8) {
    var code = std.ArrayList(u8).init(allocator);

    _ = bytecode;

    return code;
}


const Prot = struct {
    const PROT_NONE: u32 = 0x00;
    const PROT_READ: u32 = 0x01;
    const PROT_WRITE: u32 = 0x02;
    const PROT_EXEC: u32 = 0x04;
};

const MAP_PRIVATE = 0x0002;
const MAP_JIT = 0x0800;
const MAP_ANON = 0x1000;

const c = @cImport({ @cInclude("pthread.h"); });

pub fn deinit(self: jit.ExecutableJITCode) void {
    _ = self;

    std.os.munmap(@alignCast(4096 * 16, self.code));
}

pub fn execute(self: jit.ExecutableJITCode, stack: []f32) f32 {
    _ = self;
    _ = stack;

    return 0.0;
}

pub fn make_executable(_: std.mem.Allocator, code: []u8) anyerror ! jit.ExecutableJITCode {
    var unholyRegion = try std.os.mmap(null, code.len, Prot.PROT_READ | Prot.PROT_EXEC | Prot.PROT_WRITE, MAP_JIT | MAP_PRIVATE | MAP_ANON, 0, 0);

    c.pthread_jit_write_protect_np(0);

    std.mem.copy(u8, unholyRegion, code);

    c.pthread_jit_write_protect_np(1);

    return jit.ExecutableJITCode {
        .code=unholyRegion,
    };
}