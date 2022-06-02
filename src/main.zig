const std = @import("std");

const Op = enum(u32) {
    Const = 1,
    Add,
    Sub,
    Mul,
    Div,
    Print,
};

const StackError = error{OutOfMemory, OutOfValues};

fn Stack(comptime T: type) type {
    return struct {
        data: []T,
        len: usize,

        pub fn push(self: *@This(), v: T) StackError!void {
            if (self.len == self.data.len) return StackError.OutOfMemory;

            self.data[self.len] = v;
            self.len += 1;
        }

        pub fn pop(self: *@This()) StackError!T {
            if (self.len == 0) return StackError.OutOfValues;

            self.len -= 1;

            return self.data[self.len];
        }
    };
}

pub fn execute(code: []const u32, constBuf: []const f32, stack: *Stack(f32)) StackError!void {
    var pc: usize = 0;

    while (pc < code.len): (pc += 1) {
        switch (@intToEnum(Op, code[pc])) {
            Op.Const => {
                const i = code[pc + 1];
                const arg = constBuf[i];

                try stack.push(arg);
                pc += 1;
            },
            Op.Add => {
                const arg1 = try stack.pop();
                const arg2 = try stack.pop();

                try stack.push(arg1 + arg2);
            },
            Op.Print => {
                std.log.info("Print: {}\n", .{try stack.pop()});
            },
            else => @panic("illegal instruction")
        }
    }
}

pub fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
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


pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    defer { _ = gpa.deinit(); }

    const bytecode = try generate_bytecode(allocator);

    try stackVM(allocator, bytecode);

    var code = std.ArrayList(u8).init(allocator);

    var i: usize = 0;
    while (i < bytecode.code.items.len): (i += 1) {
        switch (@intToEnum(Op, bytecode.code.items[i])) {
            Op.Const => {
                i += 1;
                const offset = bytecode.code.items[i] * 4;
                const offsetBytes = @ptrCast([*]const u8, &offset);
                _ = offsetBytes;

                var instructions = [_]u8{
                    0xf3, 0x0f, 0x10, 0x83, offsetBytes[0], offsetBytes[1], offsetBytes[2], offsetBytes[3], // movss  xmm0,DWORD PTR [rbx+rcx*4]
                    0xf3, 0x0f, 0x11, 0x00, // movss DWORD PTR [rax], xmm0
                    0x48, 0x83, 0xc0, 0x04, // add rax, 0x4
                };

                try code.appendSlice(instructions[0..]);
            },
            Op.Add => {
                var instructions = [_]u8{
                    0x48, 0x83, 0xe8, 0x04, // sub rax,0x4
                    0xf3, 0x0f, 0x10, 0x40, 0xfc, // movss xmm0,DWORD PTR [rax-0x4]
                    0xf3, 0x0f, 0x58, 0x00, // addss xmm0,DWORD PTR [rax]
                    0xf3, 0x0f, 0x11, 0x40, 0xfc, // movss DWORD PTR [rax-0x4],xmm0
                };

                try code.appendSlice(instructions[0..]);
            },
            Op.Print => {
                var instructions = [_]u8{
                    0x48, 0x83, 0xe8, 0x04, // sub rax,0x4
                };

                try code.appendSlice(instructions[0..]);
            },
            else => @panic("Illegal instruction")
        }
    }


    try code.appendSlice(([_]u8{0xf3, 0x0f, 0x10, 0x40, 0xfc})[0..]);
    try code.append(0xc3);


    var unholyRegion = try std.os.mmap(null, code.items.len, Prot.PROT_READ | Prot.PROT_EXEC | Prot.PROT_WRITE, MAP_JIT | MAP_PRIVATE | MAP_ANON, 0, 0);
    std.log.info("Allocate unholy region!", .{});

    c.pthread_jit_write_protect_np(0);


    std.mem.copy(u8, unholyRegion, code.items);

    c.pthread_jit_write_protect_np(1);

    std.log.info("Wrote unholy code!", .{});


    var stackMemory: []f32 = try allocator.alloc(f32, 1024 * 1024 * 1024);
    defer code.deinit();
    defer allocator.free(stackMemory);
    defer bytecode.code.deinit();
    defer bytecode.consts.deinit();

    std.log.err("Stack base: {*}", .{ stackMemory.ptr });
    std.log.err("Consts buffer base: {*}", .{ bytecode.consts.items.ptr });
    std.log.err("Execution base: {*}", .{ unholyRegion.ptr });

    const startTime = std.time.milliTimestamp();

    var ret: f32 = 0.0;
    
    for (range(100000)) |_| {
        ret = asm volatile ("call *%%rcx" : [ret] "={xmm0}" (-> f32) :
            [unholyRegion] "{rcx}" (unholyRegion.ptr),
            [a] "{rax}" (stackMemory.ptr),
            [b] "{rbx}" (bytecode.consts.items.ptr),
        );
    }

    const endTime = std.time.milliTimestamp();

    std.log.err("Stack pointer: {*}", .{
        asm volatile("nop": [ret] "={rax}" (-> *const f32))});
    std.log.err("Executed unholy code: {}", .{ret});
    std.log.err("Stack top: {}", .{stackMemory.ptr[0]});
    std.log.err("Execution time (ms): {}", .{endTime - startTime});
}

const Bytecode = struct {
    code: std.ArrayList(u32),
    consts: std.ArrayList(f32),
};

pub fn generate_bytecode(allocator: std.mem.Allocator) anyerror ! Bytecode {
    var code = std.ArrayList(u32).init(allocator);
    var consts = std.ArrayList(f32).init(allocator);

    var rand = std.rand.DefaultPrng.init(109275125);
    _ = rand;

    const n = 1024;

    for (range(n)) |_, i| {
        try consts.append(@intToFloat(f32, i + 1));
        try code.append(@enumToInt(Op.Const));
        try code.append(@intCast(u32, i));
    }
    
    var reductionN: usize = 0;
    for (range(std.math.log2(n))) |_, i| {
        reductionN += std.math.pow(usize, 2, i);
    }

    for (range(reductionN)) |_| {
        try code.append(@enumToInt(Op.Add));
    }

    try code.append(@enumToInt(Op.Print));

    return Bytecode{ .code=code, .consts=consts };
}

pub fn stackVM(allocator: std.mem.Allocator, bytecode: Bytecode) anyerror!void {
    const startTime = std.time.milliTimestamp();

    var stackMemory: []f32 = try allocator.alloc(f32, 1024 * 1024 * 1024);
    defer allocator.free(stackMemory);

    const stack = &Stack(f32){ .data = stackMemory, .len = 0 };

    for (range(100000)) |_| {   
        try execute(bytecode.code.items, bytecode.consts.items, stack);
    }

    const endTime = std.time.milliTimestamp();

    std.log.err("Stack VM Execution time: {}\n", .{endTime - startTime});
}
