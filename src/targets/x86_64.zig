
const spec = @import("../spec.zig");
const std = @import("std");

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
