const std = @import("std");
const vm = @import("./vm.zig");
const spec = @import("./spec.zig");
const utils = @import("./utils.zig");

const ITERATIONS: usize = std.math.pow(usize, 10, 6);


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

    const bytecode = try spec.generate_bytecode(allocator);

    const jitted = try @import("targets/x86_64.zig").compile_bytecode(allocator, bytecode);

    var unholyRegion = try std.os.mmap(null, jitted.items.len, Prot.PROT_READ | Prot.PROT_EXEC | Prot.PROT_WRITE, MAP_JIT | MAP_PRIVATE | MAP_ANON, 0, 0);
    std.log.info("Allocate unholy region!", .{});

    c.pthread_jit_write_protect_np(0);

    std.mem.copy(u8, unholyRegion, jitted.items);

    c.pthread_jit_write_protect_np(1);

    std.log.info("Wrote unholy code!", .{});

    defer jitted.deinit();
    defer bytecode.code.deinit();
    defer bytecode.consts.deinit();

    var stackMemory: []f32 = try allocator.alloc(f32, 1024 * 1024 * 1024);
    defer allocator.free(stackMemory);

    { // stack vm
        std.log.err("Beginning VM execution", .{});

        const startTime = std.time.milliTimestamp();

        var stack = vm.Stack(f32).init(stackMemory);
        
        for (utils.range(ITERATIONS)) |_| {
            try vm.run(bytecode, &stack);
        }

        const endTime = std.time.milliTimestamp();
        std.log.err("VM execution time (ms): {}", .{endTime - startTime});
    }

    { // jitted code
        std.log.err("Beginning JIT execution", .{});
        std.log.err("Stack base: {*}", .{ stackMemory.ptr });
        std.log.err("Execution base: {*}", .{ unholyRegion.ptr });

        const startTime = std.time.milliTimestamp();

        for (utils.range(ITERATIONS)) |_| {
            asm volatile ("call *%%rcx" ::
                [unholyRegion] "{rcx}" (unholyRegion.ptr),
                [a] "{rdx}" (stackMemory.ptr),
            );
        }

        const ret = asm volatile("movss (%%rdx), %%xmm0": [_] "={xmm0}" (-> f32));

        const stackptr = asm volatile("nop": [_] "={rdx}" (-> *const f32));

        const endTime = std.time.milliTimestamp();

        std.log.err("Stack pointer: {*}", .{ stackptr });
        std.log.err("Executed unholy code: {}", .{ret});
        std.log.err("Stack top: {}", .{stackMemory.ptr[0]});
        std.log.err("JIT execution time (ms): {}", .{endTime - startTime});
    }
}
