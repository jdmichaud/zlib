const std = @import("std");

const c_flags = &[_][]const u8{
    "-Wall", "-D_LARGEFILE64_SOURCE=1", "-DHAVE_HIDDEN"
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlib = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });

    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .single_threaded = true,
    });
    lib_mod.addCSourceFiles(.{
        .root = zlib.path("."),
        .files = &[_][]const u8{
            "adler32.c",
            "crc32.c",
            "deflate.c",
            "infback.c",
            "inffast.c",
            "inflate.c",
            "inftrees.c",
            "trees.c",
            "zutil.c",
            "compress.c",
            "uncompr.c",
            "gzclose.c",
            "gzlib.c",
            "gzread.c",
            "gzwrite.c",
        },
        .flags = c_flags,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "z",
        .root_module = lib_mod,
    });
    lib.installHeader(zlib.path("zlib.h"), "zlib.h");
    b.installArtifact(lib);

    const dynamic_lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "z",
        .root_module = lib_mod,
    });
    const output_name = b.fmt("libz{s}.{s}", .{
        dynamic_lib.root_module.resolved_target.?.result.dynamicLibSuffix(),
        "1.3.2",
    });
    const install_step = b.addInstallArtifact(dynamic_lib, .{
        .dest_dir = .{
            .override = .lib,
        },
        .dest_sub_path = output_name,
    });
    b.getInstallStep().dependOn(&install_step.step);
    b.installArtifact(dynamic_lib);

    // Testing is about running the test binaries and checking they return 0.
    const test_step = b.step("test", "Run tests");
    const example = addTestExecutable(b, target, optimize, zlib, lib, "example", "test/example.c");
    test_step.dependOn(&example.step);
    const examplesh = addTestExecutable(b, target, optimize, zlib, dynamic_lib, "examplesh", "test/example.c");
    test_step.dependOn(&examplesh.step);
}

fn addTestExecutable(b: *std.Build, target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode, zlib: *std.Build.Dependency, lib: *std.Build.Step.Compile,
    name: []const u8, filename: []const u8) *std.Build.Step.Run {
    const test_exe_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .single_threaded = true,
    });
    test_exe_mod.addCSourceFiles(.{
        .root = zlib.path("."),
        .files = &[_][]const u8{
            filename,
        },
        .flags = c_flags,
    });
    test_exe_mod.linkLibrary(lib);
    const test_exe = b.addExecutable(.{
        .name = name,
        .root_module = test_exe_mod,
    });
    const run_exe_tests = b.addRunArtifact(test_exe);
    return run_exe_tests;
}
