/// Credit to mattnite for https://github.com/mattnite/zig-zlib/blob/a6a72f47c0653b5757a86b453b549819a151d6c7/zlib.zig
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const endsWith = std.mem.endsWith;

fn repository() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}
const dir = repository();
const package_path = dir ++ "/main.zig";
const geos_core_src_path = dir ++ "/geos/src"; // mostly cpp
const geos_core_src_path_rel = "src/geos/src"; // mostly cpp
const geos_capi_src_path = dir ++ "/geos/capi"; // cpp, but for geoc_c api
const geos_capi_src_path_rel = "src/geos/capi"; // cpp, but for geoc_c api

const shim_src = dir ++ "/shim/zig_handlers.c";

const geos_include_dirs = [_][]const u8{
    dir ++ "/vendor/geos/build/capi",
    dir ++ "/vendor/geos/build/include",
    dir ++ "/shim",
    dir ++ "/geos/include",
    dir ++ "/geos/src/deps",
};

/// c args and defines were (mostly) copied from
/// src/geos/build/CMakeFiles/geos.dir/flags.make
const geos_c_args = [_][]const u8{
    "-g0",
    "-O",
    "-DNDEBUG",
    "-DDLL_EXPORT",
    "-DUSE_UNSTABLE_GEOS_CPP_API",
    "-DGEOS_INLINE",
    "-Dgeos_EXPORTS",
    "-fPIC",
    "-ffp-contract=off",
    "-Werror",
    "-pedantic",
    "-Wall",
    "-Wextra",
    "-Wno-long-long",
    "-Wcast-align",
    "-Wchar-subscripts",
    "-Wdouble-promotion",
    "-Wpointer-arith",
    "-Wformat",
    "-Wformat-security",
    "-Wshadow",
    "-Wuninitialized",
    "-Wunused-parameter",
    "-fno-common",
    "-Wno-unknown-warning-option",
};

/// cpp args and defines were (mostly) copied from
/// src/geos/build/CMakeFiles/geos.dir/flags.make
const geos_cpp_args = [_][]const u8{
    "-g0",
    "-O",
    "-DNDEBUG",
    "-DDLL_EXPORT",
    "-DGEOS_INLINE",
    "-DUSE_UNSTABLE_GEOS_CPP_API",
    "-Dgeos_EXPORTS",
    "-fPIC",
    "-ffp-contract=off",
    "-Werror",
    "-pedantic",
    "-Wall",
    "-Wextra",
    "-Wno-long-long",
    "-Wcast-align",
    "-Wchar-subscripts",
    "-Wdouble-promotion",
    "-Wpointer-arith",
    "-Wformat",
    "-Wformat-security",
    "-Wshadow",
    "-Wuninitialized",
    "-Wunused-parameter",
    "-fno-common",
    "-Wno-unknown-warning-option",
    "-std=c++11",
};

pub const Options = struct {
    import_name: ?[]const u8 = null,
};

pub const Library = struct {
    step: *std.Build.Step.Compile,

    pub fn link(self: Library, b: *std.Build, other: *std.Build.Step.Compile, opts: Options) void {
        for (geos_include_dirs) |d| {
            other.addIncludePath(.{ .src_path = .{
                .sub_path = d,
                .owner = b,
            } });
        }
        other.linkLibrary(self.step);

        if (opts.import_name) |_| {
            // other.addPackagePath(import_name, package_path);
        }
    }
};

pub fn createCore(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !Library {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var core = b.addStaticLibrary(.{
        .name = "geos_core",
        .target = target,
        .optimize = optimize,
    });
    for (geos_include_dirs) |d| {
        core.addIncludePath(.{ .src_path = .{
            .owner = b,
            .sub_path = d,
        } });
    }
    const core_cpp_srcs = try findSources(alloc, geos_core_src_path, geos_core_src_path_rel, ".cpp");
    defer alloc.free(core_cpp_srcs);
    const core_c_srcs = try findSources(alloc, geos_core_src_path, geos_core_src_path_rel, ".c");
    defer alloc.free(core_c_srcs);
    core.linkLibCpp();
    core.addCSourceFiles(.{
        .files = core_cpp_srcs,
        .flags = &geos_cpp_args,
    });
    core.addCSourceFiles(.{
        .files = core_c_srcs,
        .flags = &geos_c_args,
    });
    core.addCSourceFile(.{ .file = .{ .src_path = .{ .owner = b, .sub_path = shim_src } }, .flags = &geos_c_args });
    return Library{ .step = core };
}

pub fn createCAPI(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !Library {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var c_api = b.addStaticLibrary(.{
        .name = "geos_c",
        .target = target,
        .optimize = optimize,
    });

    for (geos_include_dirs) |d| {
        c_api.addIncludePath(.{ .src_path = .{
            .owner = b,
            .sub_path = d,
        } });
    }
    c_api.linkLibCpp();
    const cpp_srcs = try findSources(alloc, geos_capi_src_path, geos_capi_src_path_rel, ".cpp");
    defer alloc.free(cpp_srcs);
    c_api.addCSourceFiles(.{
        .files = cpp_srcs,
        .flags = &geos_cpp_args,
    });
    return Library{ .step = c_api };
}

/// Walk the libgeos source tree and collect either .c and .cpp source files,
/// depending on the suffix. *Caller owns the returned memory.*
fn findSources(alloc: Allocator, path: []const u8, rel_path: []const u8, suffix: []const u8) ![]const []const u8 {
    const libgeos_dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
    var walker = try libgeos_dir.walk(alloc);
    defer walker.deinit();
    var list = ArrayList([]const u8).init(alloc);
    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (endsWith(u8, entry.basename, suffix)) {
            const abs_path = try std.fs.path.join(alloc, &.{ rel_path, entry.path });
            try list.append(abs_path);
        }
    }
    return list.toOwnedSlice();
}
