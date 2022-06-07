const std = @import("std");
const spec = @import("./spec.zig");

const Op = spec.Op;

pub const StackError = error{OutOfMemory, OutOfValues};

pub fn Stack(comptime T: type) type {
    return struct {
        data: []T,
        len: usize,

        const Self = @This();

        pub fn init(stackMemory: []T) Self {
            return Self{
                .data=stackMemory,
                .len=0,
            };
        }

        pub fn push(self: *Self, v: T) StackError!void {
            if (self.len == self.data.len) return StackError.OutOfMemory;

            self.data[self.len] = v;
            self.len += 1;
        }

        pub fn pop(self: *Self) StackError!T {
            if (self.len == 0) return StackError.OutOfValues;

            self.len -= 1;

            return self.data[self.len];
        }
    };
}


pub fn run(bytecode: spec.Bytecode, stack: *Stack(f32)) StackError!void {
    var pc: usize = 0;
    const code = bytecode.code;
    const constBuf = bytecode.consts;
    
    while (pc < code.items.len): (pc += 1) {
        switch (@intToEnum(Op, code.items[pc])) {
            Op.constval => {
                const i = code.items[pc + 1];
                const arg = constBuf.items[i];

                try stack.push(arg);
                pc += 1;
            },
            Op.add => {
                const arg1 = try stack.pop();
                const arg2 = try stack.pop();

                try stack.push(arg1 + arg2);
            },
            Op.sub => {
                const arg1 = try stack.pop();
                const arg2 = try stack.pop();

                try stack.push(arg2 - arg1);
            },
            Op.mul => {
                const arg1 = try stack.pop();
                const arg2 = try stack.pop();

                try stack.push(arg1 * arg2);
            },
            Op.div => {
                const arg1 = try stack.pop();
                const arg2 = try stack.pop();

                try stack.push(arg2 / arg1);
            },
            Op.pow => {
                const arg1 = try stack.pop();
                const arg2 = try stack.pop();

                try stack.push(std.math.pow(f32, arg2, arg1));
            },
            Op.sqrt => {
                const arg1 = try stack.pop();

                try stack.push(std.math.sqrt(arg1));
            },
            Op.sin => {
                const arg1 = try stack.pop();

                try stack.push(std.math.sin(arg1));
            },
            Op.cos => {
                const arg1 = try stack.pop();

                try stack.push(std.math.cos(arg1));
            },
            Op.tan => {
                const arg1 = try stack.pop();

                try stack.push(std.math.tan(arg1));
            },
            Op.print => {
                std.log.info("Print: {}\n", .{try stack.pop()});
            },
            // else => @panic("illegal instruction {}")
        }
    }
}