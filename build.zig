const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "spacezig",
        .root_source_file = .{ .path = "./src/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_gfx");
    b.installArtifact(exe);
}
