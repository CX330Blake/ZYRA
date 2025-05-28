const std = @import("std");
const decryptor = @import("decryptor.zig");

const PAYLOAD_START_MARKER = "PAYLOAD_START_MARKER";

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Get and decrypt payload
    const payload_data = try get_embedded_payload(allocator);
    defer allocator.free(payload_data);

    const key = payload_data[0];
    const encrypted_payload = payload_data[1..];
    const decrypted = try decryptor.xor_decrypt(allocator, encrypted_payload, key);
    defer allocator.free(decrypted);

    // Execute via tempfile
    try execute_via_tempfile(decrypted);
}

fn get_embedded_payload(allocator: std.mem.Allocator) ![]u8 {
    const self_binary = try std.fs.cwd().readFileAlloc(allocator, "/proc/self/exe", 100 * 1024 * 1024);
    defer allocator.free(self_binary);

    if (std.mem.lastIndexOf(u8, self_binary, PAYLOAD_START_MARKER)) |marker_start| {
        const data_start = marker_start + PAYLOAD_START_MARKER.len;
        const size_bytes = self_binary[data_start .. data_start + 8];
        const payload_size = std.mem.readInt(u64, size_bytes[0..8], .little);

        const payload_start = data_start + 8;
        const total_payload_size = payload_size + 1;
        const payload = try allocator.alloc(u8, total_payload_size);
        @memcpy(payload, self_binary[payload_start .. payload_start + total_payload_size]);
        return payload;
    }
    return error.PayloadNotFound;
}

fn execute_via_tempfile(payload: []const u8) !void {
    var temp_name_buffer: [256]u8 = undefined;
    const temp_name = try std.fmt.bufPrint(&temp_name_buffer, "/tmp/zyra_{}", .{std.time.timestamp()});

    const temp_file = try std.fs.cwd().createFile(temp_name, .{});
    defer temp_file.close();
    defer std.fs.cwd().deleteFile(temp_name) catch {};

    try temp_file.writeAll(payload);
    try temp_file.chmod(0o755);
    temp_file.close();

    var process = std.process.Child.init(&[_][]const u8{temp_name}, std.heap.page_allocator);
    process.stdin_behavior = .Inherit;
    process.stdout_behavior = .Inherit;
    process.stderr_behavior = .Inherit;
    _ = try process.spawnAndWait();
}
