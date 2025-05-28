const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Build the stub
    var build_process = std.process.Child.init(&[_][]const u8{ "zig", "build-exe", "src/packer/elf_stub.zig", "-O", "ReleaseFast", "-target", "x86_64-linux", "-fstrip", "--name", "temp_stub" }, allocator);

    try build_process.spawn();
    const result = try build_process.wait();

    if (result != .Exited or result.Exited != 0) {
        std.debug.print("Failed to build stub\n", .{}); // Added .{}
        return;
    }

    // Read the built binary
    const stub_data = try std.fs.cwd().readFileAlloc(allocator, "temp_stub", 10 * 1024 * 1024);
    defer allocator.free(stub_data);

    // Generate Zig source code with embedded binary
    const output_file = try std.fs.cwd().createFile("src/embedded_stub.zig", .{});
    defer output_file.close();

    try output_file.writeAll("// Auto-generated embedded stub binary\n");
    try output_file.writeAll("// DO NOT EDIT - Run generate_embedded_stub.zig to regenerate\n\n");
    try output_file.writeAll("pub const ELF_STUB_BINARY = [_]u8{\n");

    for (stub_data, 0..) |byte, i| {
        if (i % 16 == 0) try output_file.writeAll("    ");
        try output_file.writer().print("0x{X:0>2},", .{byte});
        if (i % 16 == 15) try output_file.writeAll("\n");
    }

    if (stub_data.len % 16 != 0) try output_file.writeAll("\n");
    try output_file.writeAll("};\n");

    // Clean up
    std.fs.cwd().deleteFile("temp_stub") catch {};

    std.debug.print("✅ Embedded stub generated: src/embedded_stub.zig\n", .{});
    std.debug.print("📦 Stub size: {} bytes\n", .{stub_data.len});
}
