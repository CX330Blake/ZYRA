const std = @import("std");
const encryptor = @import("packer/encryptor.zig");
const packer = @import("packer/packer.zig");
const build_options = @import("build_options");

const version = build_options.version_string;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Needs an input file
    if (args.len < 2) {
        try printUsage(args[0]);
        return;
    }

    var target_file: ?[]const u8 = null;
    var output_file: ?[]const u8 = null;
    var key: u8 = 0x42; // Default key
    var verbose = false; // Default verbose mode off

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try printUsage(args[0]);
            return;
        } else if (std.mem.eql(u8, arg, "--verbose")) {
            try printVersion();
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            if (i + 1 >= args.len) {
                try stdout.print("Error: -o requires output filename\n", .{});
                return;
            }
            i += 1;
            output_file = args[i];
        } else if (std.mem.eql(u8, arg, "-k") or std.mem.eql(u8, arg, "--key")) {
            if (i + 1 >= args.len) {
                try stdout.print("Error: -k requires hex key value (e.g. -k 42 means key is 0x42)\n", .{});
                return;
            }
            i += 1;
            key = try std.fmt.parseInt(u8, args[i], 16);
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            target_file = arg;
        } else {
            try stdout.print("Unknown option: {s}\n", .{arg});
            return;
        }
    }

    if (target_file == null) {
        try stdout.print("Error: No input file specified\n", .{});
        try printUsage(args[0]);
        return;
    }

    const filename = target_file.?;
    const output_filename = output_file orelse
        try getOutputFilename(allocator, filename); // Default output filename if not specified
    defer if (output_file == null) allocator.free(output_filename);

    if (verbose) {
        try printVersion();
    }

    // Pack the file
    try packFile(allocator, filename, output_filename, key, verbose);
}

fn getOutputFilename(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const dot_idx = std.mem.lastIndexOf(u8, filename, ".");
    if (dot_idx) |idx| {
        const base = filename[0..idx];
        const ext = filename[idx..]; // Includes "."
        return try std.fmt.allocPrint(allocator, "{s}_zyra{s}", .{ base, ext });
    } else {
        return try std.fmt.allocPrint(allocator, "{s}_zyra", .{filename});
    }
}

fn printVersion() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("                       Zyra Packer v{s}\n", .{version});
    try stdout.print("        Copyright (C) 2025 @CX330Blake. All rights reserved.\n\n", .{});
}

fn packFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, key: u8, verbose: bool) !void {
    const stdout = std.io.getStdOut().writer();

    if (verbose) {
        try stdout.print("Input file:     {s}\n", .{input_path});
        try stdout.print("Output file:    {s}\n", .{output_path});
        try stdout.print("Encryption key: 0x{X:0>2}\n\n", .{key});
    }

    // Read input file
    const file = std.fs.cwd().openFile(input_path, .{}) catch |err| {
        try stdout.print("Error: Cannot open input file '{s}': {}\n", .{ input_path, err });
        return;
    };
    defer file.close();

    // Maximum input is 100MB
    const input_data = file.readToEndAlloc(allocator, 100 * 1024 * 1024) catch |err| {
        try stdout.print("Error: Cannot read input file: {}\n", .{err});
        return;
    };
    defer allocator.free(input_data);

    if (verbose) try stdout.print("Encrypting...   ", .{});

    // Encrypt
    const encrypted = try encryptor.xorEncrypt(allocator, input_data, key);
    defer allocator.free(encrypted);

    if (verbose) try stdout.print("OK\nPacking...      ", .{});

    // Pack
    const packed_binary = try packer.packElfStub(allocator, encrypted, key);
    defer allocator.free(packed_binary);

    if (verbose) try stdout.print("OK\nWriting...      ", .{});

    // Write output
    const output_file_handle = std.fs.cwd().createFile(output_path, .{}) catch |err| {
        try stdout.print("Error: Cannot create output file '{s}': {}\n", .{ output_path, err });
        return;
    };
    defer output_file_handle.close();

    try output_file_handle.writeAll(packed_binary);

    // Set executable permissions on the file handle
    try output_file_handle.chmod(0o755);

    if (verbose) try stdout.print("OK\n\n", .{});

    // Summary - Fixed the format specifier
    const ratio = @as(f64, @floatFromInt(packed_binary.len)) / @as(f64, @floatFromInt(input_data.len)) * 100.0;

    try stdout.print("File size         Ratio      Format      Name\n", .{});
    try stdout.print("-------------------------------------------------\n", .{});
    try stdout.print("{d} <- {d}    {d:.1}%     zyra        {s}\n", .{ packed_binary.len, input_data.len, ratio, output_path });

    if (!verbose) {
        try stdout.print("\nPacked 1 file.\n", .{});
    }
}

fn printUsage(program_name: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print(
        \\Zyra Packer v{s} - Binary packer and obfuscator
        \\
        \\Usage: {s} [options] file
        \\
        \\Options:
        \\  -h, --help           Show this help message
        \\  -v, --verbose        Verbose output
        \\  -o, --output FILE    Output file name (default: input.packed)
        \\  -k, --key HEX        Encryption key in hex (default: 0x42)
        \\
        \\Examples:
        \\  {s} /bin/ls                    # Pack ls -> ls.packed
        \\  {s} -o myapp.exe program       # Pack program -> myapp.exe
        \\  {s} -k FF -v /usr/bin/cat      # Pack with key 0xFF, verbose
        \\
    , .{ version, program_name, program_name, program_name, program_name });
}
