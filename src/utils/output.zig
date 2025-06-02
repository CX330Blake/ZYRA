const std = @import("std");
const build_options = @import("build_options");
const arch_identifier = @import("../preprocess/arch_identifier.zig");
const stdout = std.io.getStdOut().writer();

const version = build_options.version_string;
const FileType = arch_identifier.FileType;

pub fn printError(comptime format: []const u8, args: anytype) !void {
    try stdout.print("\x1b[31m", .{});
    try stdout.print(format, args);
    try stdout.print("\x1b[0m\n", .{});
}

pub fn printSuccess(comptime format: []const u8, args: anytype) !void {
    try stdout.print("\x1b[32m", .{});
    try stdout.print(format, args);
    try stdout.print("\x1b[0m\n", .{});
}

pub fn printVersion() !void {
    const banner =
        \\___  _   _ ____ ____ 
        \\  /   \_/  |__/ |__| 
        \\ /__   |   |  \ |  | 
    ;

    // try stdout.print("                       Zyra Packer v{s}\n", .{version});
    // try stdout.print("        Copyright (C) 2025 @CX330Blake. All rights reserved.\n\n", .{});
    try stdout.print("{s}\n\n", .{banner});
    try stdout.print("Zyra Packer v{s}\n", .{version});
    try stdout.print("Copyright (C) 2025 @CX330Blake.\n", .{});
    try stdout.print("All rights reserved.\n", .{});
}

pub fn printUsage() !void {
    try printVersion();
    try stdout.print(
        \\Zyra Packer v{s} - Binary packer and obfuscator
        \\
        \\Usage: zyra [options] <FILE>
        \\
        \\Options:
        \\  -h, --help           Show this help message
        \\  -v, --verbose        Verbose output
        \\  -o, --output FILE    Output file name (default: input.zyra)
        \\  -k, --key HEX        Encryption key in hex (default: 0x42)
        \\
        \\Examples:
        \\  zyra /bin/ls                    # Pack ls -> ls.zyra
        \\  zyra -o myapp.exe program       # Pack program -> myapp.exe
        \\  zyra -k FF -v /usr/bin/cat      # Pack with key 0xFF, verbose
        \\
    , .{version});
}

pub fn printResult(packed_binary_len: usize, original_binary_len: usize, key: u8, file_type: FileType, output_path: []const u8) !void {
    const ratio = @as(f64, @floatFromInt(packed_binary_len)) / @as(f64, @floatFromInt(original_binary_len)) * 100.0;
    try stdout.print("──────────────────┬────────────────────────\n", .{});
    try stdout.print(" 📁 File size     │ {d} <- {d}\n", .{ packed_binary_len, original_binary_len });
    try stdout.print(" 📉 Ratio         │ {d:.1}%\n", .{ratio});
    try stdout.print(" 🔑 Key           │ 0x{x}\n", .{key});
    try stdout.print(" 🖥️ Format        │ {s}\n", .{@tagName(file_type)});
    try stdout.print(" 👀 Name          │ {s}\n", .{output_path});
    try stdout.print("──────────────────┴────────────────────────\n", .{});
}
