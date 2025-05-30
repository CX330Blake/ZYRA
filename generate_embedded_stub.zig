const std = @import("std");

const StubTarget = struct {
    name: []const u8,
    target: []const u8,
    extension: []const u8, // For .exe on Windows, "" on Linux
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Define your desired output stubs here
    const stubs = [_]StubTarget{
        .{ .name = "elf_x86_64", .target = "x86_64-linux", .extension = "" },
        .{ .name = "elf_x86", .target = "x86-linux", .extension = "" },
        .{ .name = "pe_x86_64", .target = "x86_64-windows", .extension = "" },
        .{ .name = "pe_x86", .target = "x86-windows", .extension = "" },
    };

    for (stubs) |stub| {
        // Build the stub
        const temp_output = try std.fmt.allocPrint(allocator, "temp_stub_{s}{s}", .{ stub.name, stub.extension });
        defer allocator.free(temp_output);

        var build_args = std.ArrayList([]const u8).init(allocator);
        defer build_args.deinit();
        try build_args.append("zig");
        try build_args.append("build-exe");
        try build_args.append("src/packer/stub.zig");
        try build_args.append("-O");
        try build_args.append("ReleaseFast");
        try build_args.append("-target");
        try build_args.append(stub.target);
        try build_args.append("-fstrip");
        try build_args.append("--name");
        try build_args.append(temp_output);

        std.debug.print("👾 Building stub for {s}...\n", .{stub.name});
        var build_process = std.process.Child.init(build_args.items, allocator);
        try build_process.spawn();
        const result = try build_process.wait();

        if (result != .Exited or result.Exited != 0) {
            std.debug.print("Failed to build stub {s}\n", .{stub.name});
            continue;
        }

        // Read built stub binary
        var stub_file_path = temp_output;
        var stub_file_path_allocated = false;
        if (std.mem.endsWith(u8, stub.target, "windows")) {
            stub_file_path = try std.fmt.allocPrint(allocator, "{s}.exe", .{temp_output});
            stub_file_path_allocated = true;
        }

        // ... now use stub_file_path for ALL file operations ...
        const temp_stub_file = std.fs.cwd().openFile(stub_file_path, .{}) catch |err| switch (err) {
            error.FileNotFound => {
                std.debug.print("Stub file '{s}' was not produced by the build step!\n", .{stub_file_path});
                if (stub_file_path_allocated) allocator.free(stub_file_path);
                continue;
            },
            else => return err,
        };
        defer temp_stub_file.close();

        const stub_stat = try temp_stub_file.stat();
        const stub_size = stub_stat.size;

        const stub_data = try std.fs.cwd().readFileAlloc(allocator, stub_file_path, stub_size);
        defer allocator.free(stub_data);

        if (stub_file_path_allocated) allocator.free(stub_file_path);

        // Generate embedded stub Zig file in src/packer/embedded_stubs/
        const output_file_name = try std.fmt.allocPrint(allocator, "src/packer/embedded_stubs/embedded_{s}.zig", .{stub.name});
        defer allocator.free(output_file_name);

        const output_file = try std.fs.cwd().createFile(output_file_name, .{});
        defer output_file.close();

        try output_file.writeAll("// Auto-generated embedded stub binary\n");
        try output_file.writeAll("// DO NOT EDIT - Run generate_embedded_stubs.zig to regenerate\n\n");
        try output_file.writeAll("pub const STUB_BINARY = [_]u8{\n");

        for (stub_data, 0..) |byte, i| {
            if (i % 16 == 0) try output_file.writeAll("    ");
            try output_file.writer().print("0x{X:0>2},", .{byte});
            if (i % 16 == 15) try output_file.writeAll("\n");
        }
        if (stub_data.len % 16 != 0) try output_file.writeAll("\n");
        try output_file.writeAll("};\n");

        // Clean up all files starting with temp_output name as prefix
        var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (std.mem.startsWith(u8, entry.name, temp_output)) {
                std.fs.cwd().deleteFile(entry.name) catch {};
            }
        }
        std.debug.print("✅ Embedded stub generated: {s}\n", .{output_file_name});
        std.debug.print("📦 Stub size: {} bytes\n", .{stub_data.len});
        std.debug.print("-----------------------------------------\n", .{});
    }
}
