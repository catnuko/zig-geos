/// this build.zig shows how to link libgeos with an example_exe and with your unit tests.
const std = @import("std");
const libgeos = @import("./build_geos.zig");

const Example = struct {
    cmd: []const u8,
    src: []const u8,
    descr: []const u8,
};

const examples = [_]Example{
    Example{ .cmd = "run-ex1", .src = "examples/ex1.zig", .descr = "Ex 1: Reads two WKT representations and calculates the intersection, prints it out, and cleans up." },
    Example{
        .cmd = "run-ex1-ts",
        .src = "examples/ex1_threadsafe.zig",
        .descr = "Ex 1 (threadsafe): Same but using re-entrant api.",
    },
    Example{ .cmd = "run-ex2", .src = "examples/ex2.zig", .descr = "Ex 2: Reads one geometry and does a high-performance prepared geometry operations to place random points inside it." },
    Example{
        .cmd = "run-ex3",
        .src = "examples/ex3.zig",
        .descr = "Ex 3: Build a spatial index and search it for a nearest pair.",
    },
     Example{
        .cmd = "run-ex4",
        .src = "examples/ex4.zig",
        .descr = "Ex 4: Read and write geojson.",
    },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const geos_dep = b.lazyDependency("geos", .{
        .target = target,
        .optimize = optimize,
    }) orelse unreachable;
    // the C api depends on the core C++ lib, so build and link both of them.
    const core_lib = try libgeos.createCore(b, geos_dep, target, optimize);
    const capi_lib = try libgeos.createCAPI(b, geos_dep, target, optimize);

    const lib_mod = b.addModule("root", .{
        .root_source_file = b.path("src/c_api.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib_static = b.addStaticLibrary(.{
        .name = "zig-geos",
        .root_source_file = b.path("src/c_api.zig"),
        .target = target,
        .optimize = optimize,
    });
    libgeos.addIncludePath(b,lib_static,geos_dep);
    lib_static.linkLibCpp();
    lib_static.linkLibrary(core_lib);
    lib_static.linkLibrary(capi_lib);

    const module = b.addModule("default_handlers", .{
        .root_source_file = b.path("src/shim/default_handlers.zig"),
        .target = target,
        .optimize = optimize,
    });
    for (examples) |ex| {
        const example_exe = b.addExecutable(.{
            .name = ex.cmd,
            .root_source_file = b.path(ex.src),
            .target = target,
            .optimize = optimize,
        });
        libgeos.addIncludePath(b,example_exe,geos_dep);
        example_exe.linkLibrary(lib_static);
        example_exe.root_module.addImport("default_handlers", module);
        example_exe.root_module.addImport("zig-geos", lib_mod);
        b.installArtifact(example_exe);

        const run_cmd = b.addRunArtifact(example_exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step(ex.cmd, ex.descr);
        run_step.dependOn(&run_cmd.step);
    }
}
