const std = @import("std");
const output = @import("../utils/output.zig");

pub const FileFormat = enum {
    elf,
    pe,
    unknown,
};

pub const Arch = enum {
    x86,
    x64,
    unknown,
};

pub const BinType = struct {
    format: FileFormat,
    arch: Arch,
};

pub const FileType = enum {
    elf_x86,
    elf_x86_64,
    pe_x86,
    pe_x86_64,
    unknown,
};

/// Attempts to identify the file format and architecture.
/// Returns a BinType, or .unknown/.unknown if not recognized.
pub fn identifyExecutableFormat(path: []const u8) !BinType {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buffer: [64]u8 = undefined;
    const read_len = try file.readAll(&buffer);

    // ELF detection
    if (read_len >= 20 and std.mem.eql(u8, buffer[0..4], "\x7FELF")) {
        const class = buffer[4]; // 1 = 32-bit, 2 = 64-bit
        const machine = @as(u16, buffer[18]) | (@as(u16, buffer[19]) << 8);

        if (class == 1 and machine == 3) {
            return BinType{ .format = .elf, .arch = .x86 };
        } else if (class == 2 and machine == 62) {
            return BinType{ .format = .elf, .arch = .x64 };
        } else {
            return BinType{ .format = .elf, .arch = .unknown };
        }
    }

    // PE detection
    if (read_len >= 0x40 and buffer[0] == 'M' and buffer[1] == 'Z') {
        // PE header offset
        const pe_offset = @as(u32, buffer[0x3C]) | (@as(u32, buffer[0x3D]) << 8) | (@as(u32, buffer[0x3E]) << 16) | (@as(u32, buffer[0x3F]) << 24);
        try file.seekTo(pe_offset);
        var pe_hdr: [6]u8 = undefined;
        _ = try file.readAll(&pe_hdr);

        if (std.mem.eql(u8, buffer[0..4], &[_]u8{ 'P', 'E', 0, 0 })) {
            return BinType{ .format = .unknown, .arch = .unknown };
        }
        const machine = pe_hdr[4] | (@as(u16, pe_hdr[5]) << 8);
        if (machine == 0x14c) {
            return BinType{ .format = .pe, .arch = .x86 };
        } else if (machine == 0x8664) {
            return BinType{ .format = .pe, .arch = .x64 };
        } else {
            return BinType{ .format = .pe, .arch = .unknown };
        }
    }

    return BinType{ .format = .unknown, .arch = .unknown };
}
