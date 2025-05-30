const std = @import("std");
// TODO: support more architecture like PE and Mach-O
const embedded_elf_x86_stub = @import("embedded_stubs/embedded_elf_x86.zig");
const embedded_elf_x86_64_stub = @import("embedded_stubs/embedded_elf_x86_64.zig");
const embedded_pe_x86 = @import("embedded_stubs/embedded_pe_x86.zig");
const embedded_pe_x86_64 = @import("embedded_stubs/embedded_pe_x86_64.zig");

const arch_identifier = @import("../preprocess/arch_identifier.zig");
const BinType = arch_identifier.BinType;
const FileFormat = arch_identifier.FileFormat;
const Arch = arch_identifier.Arch;

pub fn packStub(
    allocator: std.mem.Allocator,
    bin_type: BinType,
    encrypted_payload: []const u8,
    key: u8,
) ![]u8 {
    const stub_binary = switch (bin_type.format) {
        .elf => switch (bin_type.arch) {
            .x86 => &embedded_elf_x86_stub.STUB_BINARY,
            .x64 => &embedded_elf_x86_64_stub.STUB_BINARY,
            else => return error.UnsupportedArch,
        },
        .pe => switch (bin_type.arch) {
            .x86 => &embedded_pe_x86.STUB_BINARY,
            .x64 => &embedded_pe_x86_64.STUB_BINARY,
            else => return error.UnsupportedArch,
        },
        else => return error.UnsupportedFormat,
    };

    const marker = "PAYLOAD_START_MARKER";
    const total_size = stub_binary.len + marker.len + 8 + 1 + encrypted_payload.len;
    var packed_binary = try allocator.alloc(u8, total_size);

    var offset: usize = 0;
    @memcpy(packed_binary[offset .. offset + stub_binary.len], stub_binary);
    offset += stub_binary.len;

    @memcpy(packed_binary[offset .. offset + marker.len], marker);
    offset += marker.len;

    var size_bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &size_bytes, encrypted_payload.len, .little);
    @memcpy(packed_binary[offset .. offset + 8], &size_bytes);
    offset += 8;

    packed_binary[offset] = key;
    offset += 1;

    @memcpy(packed_binary[offset .. offset + encrypted_payload.len], encrypted_payload);

    return packed_binary;
}
