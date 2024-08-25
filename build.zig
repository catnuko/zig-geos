/// this build.zig shows how to link libgeos with an exe and with your unit tests.
const std = @import("std");
const libgeos = @import("src/libgeos.zig");

const Example = struct {
    cmd: []const u8,
    src: []const u8,
    descr: []const u8,
};

const examples = [_]Example{
    Example{ .cmd = "run-ex1", .src = "src/examples/ex1.zig", .descr = "Ex 1: Reads two WKT representations and calculates the intersection, prints it out, and cleans up." },
    Example{
        .cmd = "run-ex1-ts",
        .src = "src/examples/ex1_threadsafe.zig",
        .descr = "Ex 1 (threadsafe): Same but using re-entrant api.",
    },
    Example{ .cmd = "run-ex2", .src = "src/examples/ex2.zig", .descr = "Ex 2: Reads one geometry and does a high-performance prepared geometry operations to place random points inside it." },
    Example{
        .cmd = "run-ex3",
        .src = "src/examples/ex3.zig",
        .descr = "Ex 3: Build a spatial index and search it for a nearest pair.",
    },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    // const mode = b.standardReleaseOptions();
    const optimize = b.standardOptimizeOption(.{});

    // the C api depends on the core C++ lib, so build and link both of them.
    const core_lib = try libgeos.createCore(b, target, optimize);
    const capi_lib = try libgeos.createCAPI(b, target, optimize);

    // 构建一个单元测试的 Compile
    const tests = b.addTest(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    // 执行单元测试
    const run_exe_unit_tests = b.addRunArtifact(tests);

    core_lib.link(b, tests, .{});
    capi_lib.link(b, tests, .{ .import_name = "geos" });

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    const module = b.addModule("default_handlers", .{
        .root_source_file = b.path("src/shim/default_handlers.zig"),
        .target = target,
        .optimize = optimize,
    });
    // add all examples
    for (examples) |ex| {
        const exe = b.addExecutable(.{
            .name = ex.cmd,
            .root_source_file = b.path(ex.src),
            .target = target,
            .optimize = optimize,
        });
        // exe.addPackagePath("default_handlers", "src/shim/default_handlers.zig");
        exe.root_module.addImport("default_handlers", module);
        core_lib.link(b, exe, .{});
        capi_lib.link(b, exe, .{ .import_name = "geos" });
        b.installArtifact(exe);

        // const run_cmd = exe.run();
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step(ex.cmd, ex.descr);
        run_step.dependOn(&run_cmd.step);
    }
}
