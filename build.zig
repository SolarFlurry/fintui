const std = @import("std");

pub fn build(b: *std.Build) !void {
    const build_examples = b.option(bool, "examples", "Build the examples in the examples directory") orelse false;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_fintui = b.addLibrary(.{
        .name = "fintui",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/fintui.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    if (!build_examples) return;

    const examples_dir = try b.root.openDir(b.graph.io, "examples", .{ .iterate = true });
    defer examples_dir.close(b.graph.io);

    var iter = examples_dir.iterateAssumeFirstIteration();
    while (try iter.next(b.graph.io)) |entry| {
        var basename: []const u8 = undefined;
        var mod_path: std.Build.LazyPath = undefined;

        switch (entry.kind) {
            .file => {
                if (!std.mem.endsWith(u8, entry.name, ".zig")) continue;

                basename = std.fs.path.basename(entry.name);
                basename = basename[0 .. basename.len - 4];
                mod_path = b.path(try std.fs.path.join(b.allocator, &.{ "examples", entry.name }));
            },
            .directory => {
                basename = std.fs.path.basename(entry.name);
                mod_path = b.path(try std.fs.path.join(b.allocator, &.{ "examples", entry.name, "main.zig" }));
            },
            else => continue,
        }

        const exe_example = b.addExecutable(.{
            .name = try std.mem.join(b.allocator, "", &.{ "libtest_", basename }),
            .root_module = b.createModule(.{
                .root_source_file = mod_path,
                .target = target,
                .optimize = optimize,
            }),
        });

        exe_example.root_module.addImport("fintui", lib_fintui.root_module);

        b.installArtifact(exe_example);
    }
}
