const std = @import("std");

pub fn build(b: *std.Build) !void {
    const build_examples = b.option(bool, "examples", "Build the examples in the src/examples directory") orelse false;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_fintui = b.addLibrary(.{
        .name = "fintui",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    if (!build_examples) return;

    const examples_dir = try b.build_root.handle.openDir(b.graph.io, "src/examples", .{ .iterate = true });
    defer examples_dir.close(b.graph.io);

    var iter = examples_dir.iterateAssumeFirstIteration();
    while (try iter.next(b.graph.io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".zig")) continue;

        const basename = std.fs.path.basename(entry.name);

        const exe_example = b.addExecutable(.{
            .name = try std.mem.join(b.allocator, "", &.{ "libtest_", basename[0 .. basename.len - 4] }),
            .root_module = b.createModule(.{
                .root_source_file = b.path(try std.fs.path.join(b.allocator, &.{ "src/examples", entry.name })),
                .target = target,
                .optimize = optimize,
            }),
        });

        exe_example.root_module.addImport("fintui", lib_fintui.root_module);

        b.installArtifact(exe_example);
    }
}
