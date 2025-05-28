const std = @import("std");

const ELF_STUB_TEMPLATE = @embedFile("");

pub fn pack_elf_stub(allocator: std.mem.Allocator, encrypted_payload: []const u8, key: u8) ![]u8 {
    // Magic markers to find and replace in the stub
    const PAYLOAD_MARKER = "PAYLOAD_DATA_PLACEHOLDER";
    const KEY_MARKER = "KEY_PLACEHOLDER_42";
    const SIZE_MARKER = "SIZE_PLACEHOLDER_12345678";

    var stub_data = try allocator.dupe(u8, ELF_STUB_TEMPLATE);

    // Find and replace payload size
    const size_str = try std.fmt.allocPrint(allocator, "{d}", .{encrypted_payload.len});
    defer allocator.free(size_str);

    if (std.mem.indexOf(u8, stub_data, SIZE_MARKER)) |size_pos| {
        // Replace size marker with actual size (pad with spaces if needed)
        const marker_len = SIZE_MARKER.len;
        @memset(stub_data[size_pos .. size_pos + marker_len], ' ');
        @memcpy(stub_data[size_pos .. size_pos + size_str.len], size_str);
    }

    // Find and replace key
    if (std.mem.indexOf(u8, stub_data, KEY_MARKER)) |key_pos| {
        stub_data[key_pos] = key;
    }

    // Find payload marker and replace with actual encrypted data
    if (std.mem.indexOf(u8, stub_data, PAYLOAD_MARKER)) |payload_pos| {
        // Calculate new total size
        const new_size = stub_data.len - PAYLOAD_MARKER.len + encrypted_payload.len;
        var new_stub = try allocator.alloc(u8, new_size);

        // Copy before marker
        @memcpy(new_stub[0..payload_pos], stub_data[0..payload_pos]);

        // Copy encrypted payload
        @memcpy(new_stub[payload_pos .. payload_pos + encrypted_payload.len], encrypted_payload);

        // Copy after marker
        const after_marker_start = payload_pos + PAYLOAD_MARKER.len;
        @memcpy(new_stub[payload_pos + encrypted_payload.len ..], stub_data[after_marker_start..]);

        allocator.free(stub_data);
        return new_stub;
    }

    return stub_data;
}
