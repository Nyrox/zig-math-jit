
const spec = @import("../spec.zig");
const std = @import("std");
const jit = @import("./jit.zig");

const Bytecode = spec.Bytecode;
const Op = spec.Op;

pub fn compile_bytecode(allocator: std.mem.Allocator, bytecode: Bytecode) anyerror ! std.ArrayList(u8) {
    var code = std.ArrayList(u8).init(allocator);

    var i: usize = 0;
    while (i < bytecode.code.items.len): (i += 1) {
        switch (@intToEnum(Op, bytecode.code.items[i])) {
            Op.constval => {
                i += 1;
                const offset = bytecode.code.items[i] * 4;
                const offsetBytes = @ptrCast([*]const u8, &offset);
                _ = offsetBytes;
                const val = bytecode.consts.items[offset / 4];
                const valBytes = @ptrCast([*]const u8, &val);

                var instructions = [_]u8{
                    // 0xf3, 0x0f, 0x10, 0x83, offsetBytes[0], offsetBytes[1], offsetBytes[2], offsetBytes[3], // movss  xmm0,DWORD PTR [rbx+rcx*4]
                    // 0xf3, 0x0f, 0x11, 0x00, // movss DWORD PTR [rax], xmm0
                    0xc7, 0x02, valBytes[0], valBytes[1], valBytes[2], valBytes[3], // mov DWORD PTR [rax], val
                    0x48, 0x83, 0xc2, 0x04, // add rax, 0x4
                };

                try code.appendSlice(instructions[0..]);
            },
            Op.add => {
                var instructions = [_]u8{
                    0x48, 0x83, 0xea, 0x04, // sub rdx,0x4
                    0xf3, 0x0f, 0x10, 0x42, 0xfc, // movss xmm0,DWORD PTR [rdx-0x4]
                    0xf3, 0x0f, 0x58, 0x02, // addss xmm0,DWORD PTR [rdx]
                    0xf3, 0x0f, 0x11, 0x42, 0xfc, // movss DWORD PTR [rdx-0x4],xmm0
                };

                try code.appendSlice(instructions[0..]);
            },
            Op.print => {
                var instructions = [_]u8{
                    0x48, 0x83, 0xea, 0x04, // sub rdx,0x4
                };

                try code.appendSlice(instructions[0..]);
            },
            else => @panic("Illegal instruction")
        }
    }


    try code.appendSlice(([_]u8{0xf3, 0x0f, 0x10, 0x42, 0xfc})[0..]); // movss %xmm0, DWORD PTR [rdx]
    try code.append(0xc3); // ret

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
    std.os.munmap(@alignCast(4096, self.code));
}

pub fn execute(self: jit.ExecutableJITCode, stack: []f32) f32 {
    asm volatile ("call *%%rcx" ::
        [unholyRegion] "{rcx}" (self.code.ptr),
        [a] "{rdx}" (stack.ptr),
    );

    return asm volatile("movss (%%rdx), %%xmm0": [ret] "={xmm0}" (-> f32));
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