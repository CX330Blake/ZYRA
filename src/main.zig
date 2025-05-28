const std = @import("std");
const encryptor = @import("packer/encryptor.zig");
const packer = @import("packer/packer.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try stdout.print("Usage: {s} <filename>\n", .{args[0]});
        return;
    }
    const filename = args[1];

    // Read file
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const input_bin = try file.readToEndAlloc(allocator, 20 * 1024 * 1024); // at most 10MB
    defer allocator.free(input_bin);

    const key: u8 = 0x42;

    // Encrypt the payload
    const encrypted = try encryptor.xor_encrypt(allocator, input_bin, key);
    defer allocator.free(encrypted);

    // Pack the stub with encrypted payload
    const packed_binary = try packer.pack_elf_stub(allocator, encrypted, key);
    defer allocator.free(packed_binary);

    // Write packed binary
    const output_filename = try std.fmt.allocPrint(allocator, "{s}_zyra", .{filename});
    defer allocator.free(output_filename);
    const out_file = try std.fs.cwd().createFile(output_filename, .{});
    defer out_file.close();

    try out_file.writeAll(packed_binary);

    // Make it executable
    try std.fs.cwd().chmod(output_filename, 0o755);

    // Finish
    try stdout.print("Packed binary created: {s}\n", .{output_filename});
}
