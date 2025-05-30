const std = @import("std");
// TODO: support more architecture like PE and Mach-O
const embedded_elf_stub = @import("../embedded_elf_stub.zig");

pub fn packElfStub(allocator: std.mem.Allocator, encrypted_payload: []const u8, key: u8) ![]u8 {
    const stub_binary = &embedded_elf_stub.ELF_STUB_BINARY;

    // Simply append our data to the end of the stub binary
    // The stub will scan for the marker and read from there
    const marker = "PAYLOAD_START_MARKER";

    // Calculate total size: stub + marker + size + key + payload
    const total_size = stub_binary.len + marker.len + 8 + 1 + encrypted_payload.len;
    var packed_binary = try allocator.alloc(u8, total_size);

    var offset: usize = 0;

    // Copy the entire stub binary
    @memcpy(packed_binary[offset .. offset + stub_binary.len], stub_binary);
    offset += stub_binary.len;

    // Append marker
    @memcpy(packed_binary[offset .. offset + marker.len], marker);
    offset += marker.len;

    // Append payload size (8 bytes, little endian)
    var size_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &size_bytes, encrypted_payload.len, .little);
    @memcpy(packed_binary[offset .. offset + 8], &size_bytes);
    offset += 8;

    // Append key
    packed_binary[offset] = key;
    offset += 1;

    // Append encrypted payload
    @memcpy(packed_binary[offset .. offset + encrypted_payload.len], encrypted_payload);

    return packed_binary;
}
