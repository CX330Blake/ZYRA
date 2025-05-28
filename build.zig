const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define version
    const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

    // Create build options to pass version to the code
    const options = b.addOptions();
    options.addOption([]const u8, "version_string", b.fmt("{}", .{version}));
    options.addOption(u32, "version_major", version.major);
    options.addOption(u32, "version_minor", version.minor);
    options.addOption(u32, "version_patch", version.patch);

    // Build the stubs first
    const gen_stub = b.addSystemCommand(&[_][]const u8{
        "zig", "run", "generate_embedded_stub.zig",
    });

    const exe = b.addExecutable(.{
        .name = "zyra",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .version = version,
    });

    exe.root_module.addOptions("build_options", options);

    exe.step.dependOn(&gen_stub.step);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the packer");
    run_step.dependOn(&run_cmd.step);
}
