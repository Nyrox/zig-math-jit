const std = @import("std");
const utils = @import("./utils.zig");

pub const Op = enum(u32) {
    constval = 1,
    add,
    sub,
    mul,
    div,
    pow,
    sqrt,
    sin,
    cos,
    tan,
    print,
};


pub const Bytecode = struct {
    code: std.ArrayList(u32),
    consts: std.ArrayList(f32),
};

pub fn generate_bytecode(allocator: std.mem.Allocator) anyerror ! Bytecode {
    var code = std.ArrayList(u32).init(allocator);
    var consts = std.ArrayList(f32).init(allocator);

    var rand = std.rand.DefaultPrng.init(109275125);
    _ = rand;

    const n = 4096;

    for (utils.range(n)) |_, i| {
        try consts.append(rand.random().float(f32) * 5.0);
        try code.append(@enumToInt(Op.constval));
        try code.append(@intCast(u32, i));
    }
    
    var reductionN: usize = 0;
    for (utils.range(std.math.log2(n))) |_, i| {
        reductionN += std.math.pow(usize, 2, i);
    }

    for (utils.range(reductionN)) |_| {
        try code.append(@enumToInt(Op.add));
    }

    try code.append(@enumToInt(Op.print));

    return Bytecode{ .code=code, .consts=consts };
}
