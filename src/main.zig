const std = @import("std");
const vm = @import("./vm.zig");
const spec = @import("./spec.zig");
const utils = @import("./utils.zig");
const jit = @import("./targets/jit.zig").get_jit();

const ITERATIONS: usize = std.math.pow(usize, 10, 6);


pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    defer { _ = gpa.deinit(); }

    const bytecode = try spec.generate_bytecode(allocator);
    const jitted = try jit.compile_bytecode(allocator, bytecode);
    const executable = try jit.make_executable(allocator, jitted.items);

    std.log.info("Wrote unholy code!", .{});

    defer jitted.deinit();
    defer bytecode.code.deinit();
    defer bytecode.consts.deinit();
    defer jit.deinit(executable);

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
        std.log.err("Execution base: {*}", .{ executable.code });

        const startTime = std.time.milliTimestamp();

        var ret: f32 = 0.0;
        for (utils.range(ITERATIONS)) |_| {
            ret = jit.execute(executable, stackMemory);
        }

        const endTime = std.time.milliTimestamp();

        std.log.err("Executed unholy code: {}", .{ret});
        std.log.err("Stack top: {}", .{stackMemory.ptr[0]});
        std.log.err("JIT execution time (ms): {}", .{endTime - startTime});
    }
}
