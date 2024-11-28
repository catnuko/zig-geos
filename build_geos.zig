/// Credit to mattnite for https://github.com/mattnite/zig-zlib/blob/a6a72f47c0653b5757a86b453b549819a151d6c7/zlib.zig
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const endsWith = std.mem.endsWith;
pub fn addIncludePath(b:*std.Build,libOrExe:*std.Build.Step.Compile,geos_dep:*std.Build.Dependency) void {
    const include_dirs = [_][]const u8{
        "/home/catnuko/zig-geos/src/vendor/geos/build/capi",
        "/home/catnuko/zig-geos/src/vendor/geos/build/include",
        "/home/catnuko/zig-geos/src/shim",
    };
    for (include_dirs) |d| {
        // libOrExe.addIncludePath(b.path(d));
        libOrExe.addIncludePath(.{ .src_path = .{
            .owner = b,
            .sub_path = d,
        } });
    }
    libOrExe.addIncludePath(geos_dep.path("include"));
    libOrExe.addIncludePath(geos_dep.path("src/deps"));
}
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
    "-std=c++14",
};

pub const Options = struct {
    import_name: ?[]const u8 = null,
};

pub fn createCore(b: *std.Build,geos_dep:*std.Build.Dependency, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var core = b.addStaticLibrary(.{
        .name = "geos_core",
        .target = target,
        .optimize = optimize,
    });
    addIncludePath(b,core,geos_dep);

    core.linkLibCpp();
    
    const root = geos_dep.path(".");
    const src_dir = geos_dep.path("src").getPath(b);

    const core_cpp_srcs = try findSources(alloc,src_dir,"src", ".cpp");
    defer alloc.free(core_cpp_srcs);
    core.addCSourceFiles(.{
        .root = root,
        .files = core_cpp_srcs,
        .flags = &geos_cpp_args,
    });

    const core_c_srcs = try findSources(alloc, src_dir, "src", ".c");
    defer alloc.free(core_c_srcs);
    core.addCSourceFiles(.{
        .root = root,
        .files = core_c_srcs,
        .flags = &geos_c_args,
    });

    core.addCSourceFile(.{ .file = b.path("src/shim/zig_handlers.c"), .flags = &geos_c_args });
    return core;
}

pub fn createCAPI(b: *std.Build,geos_dep:*std.Build.Dependency, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    var c_api = b.addStaticLibrary(.{
        .name = "geos_c",
        .target = target,
        .optimize = optimize,
    });
    addIncludePath(b,c_api,geos_dep);

    c_api.linkLibCpp();
    const root = geos_dep.path(".");
    const capi_dir = geos_dep.path("capi").getPath(b);

    const cpp_srcs = try findSources(alloc,capi_dir,"capi", ".cpp");
    defer alloc.free(cpp_srcs);
    c_api.addCSourceFiles(.{
        .root = root,
        .files = cpp_srcs,
        .flags = &geos_cpp_args,
    });

    return c_api;
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
