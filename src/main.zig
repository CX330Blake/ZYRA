const std = @import("std");

fn encrypt(allocator: std.mem.Allocator, input_bin: []const u8, key: u8) ![]u8 {
    const encrypted = try allocator.alloc(u8, input_bin.len);
    for (input_bin, 0..) |byte, i| {
        encrypted[i] = byte ^ key;
    }
    return encrypted;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();
    const args = try std.process.argsAlloc(std.heap.page_allocator);
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

    const encrypted: []u8 = try encrypt(allocator, input_bin, key);
    defer allocator.free(encrypted);

    const output_filename = try std.fmt.allocPrint(allocator, "{s}_zyra", .{filename});
    defer allocator.free(output_filename);
    const out_file = try std.fs.cwd().createFile(output_filename, .{});
    defer out_file.close();

    try out_file.writeAll(encrypted);
}
