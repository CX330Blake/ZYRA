const std = @import("std");
const encryptor = @import("packer/encryptor.zig");
const packer = @import("packer/packer.zig");
const arch_identifier = @import("preprocess/arch_identifier.zig");
const output = @import("utils/output.zig");

const FileFormat = arch_identifier.FileFormat;
const Arch = arch_identifier.Arch;
const BinType = arch_identifier.BinType;
const FileType = arch_identifier.FileType;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Needs an input file
    if (args.len < 2) {
        try output.printUsage();
        return;
    }

    var target_file: ?[]const u8 = null;
    var output_file: ?[]const u8 = null;
    var key: u8 = 0x42; // Default key
    var verbose = false; // Default verbose mode off

    // Parsing args
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];

        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            try output.printUsage();
            return;
        } else if (std.mem.eql(u8, arg, "--version")) {
            try output.printVersion();
            return;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            if (i + 1 >= args.len) {
                try output.printError("Error: -o requires output filename\n", .{});
                return;
            }
            i += 1;
            output_file = args[i];
        } else if (std.mem.eql(u8, arg, "-k") or std.mem.eql(u8, arg, "--key")) {
            if (i + 1 >= args.len) {
                try output.printError("Error: -k requires hex key value (e.g. -k 42 means key is 0x42)\n", .{});
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
        try output.printError("Error: No input file specified\n", .{});
        try output.printUsage();
        return;
    }

    const filename = target_file.?;
    const output_filename = output_file orelse
        try getOutputFilename(allocator, filename); // Default output filename if not specified
    defer if (output_file == null) allocator.free(output_filename);

    // Print the version banner
    try output.printVersion();

    // Identify the arch and format
    const bin_type: BinType = arch_identifier.identifyExecutableFormat(filename) catch {
        try output.printError("Error: {s} not exist\n", .{filename});
        return;
    };

    // Pack the file
    try packFile(allocator, filename, bin_type, output_filename, key, verbose);
}

fn getOutputFilename(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const dot_idx = std.mem.lastIndexOf(u8, filename, ".");
    if (dot_idx) |idx| {
        const base = filename[0..idx];
        const ext = filename[idx..]; // Includes "."
        return try std.fmt.allocPrint(allocator, "{s}.zyra{s}", .{ base, ext });
    } else {
        return try std.fmt.allocPrint(allocator, "{s}.zyra", .{filename});
    }
}

fn packFile(allocator: std.mem.Allocator, input_path: []const u8, bin_type: BinType, output_path: []const u8, key: u8, verbose: bool) !void {
    const stdout = std.io.getStdOut().writer();

    const format = bin_type.format;
    const arch = bin_type.arch;
    var file_type: FileType = .unknown;

    if (format == .elf and arch == .x64) {
        file_type = .elf_x86_64;
    } else if (format == .elf and arch == .x86) {
        file_type = .elf_x86;
    } else if (format == .pe and arch == .x64) {
        file_type = .pe_x86_64;
    } else if (format == .pe and arch == .x86) {
        file_type = .pe_x86;
    } else {
        try output.printError("Error: Unknown file format or architecture\n", .{});
        return;
    }

    if (verbose) {
        try stdout.print("Input file:     {s}\n", .{input_path});
        try stdout.print("File format:     {s}\n", .{@tagName(file_type)});
        try stdout.print("Output file:    {s}\n", .{output_path});
        try stdout.print("Encryption key: 0x{X:0>2}\n\n", .{key});
    }

    // Read input file
    const file = std.fs.cwd().openFile(input_path, .{}) catch |err| {
        try output.printError("Error: Cannot open input file '{s}': {}\n", .{ input_path, err });
        return;
    };
    defer file.close();

    // Maximum input is 100MB
    const input_data = file.readToEndAlloc(allocator, 100 * 1024 * 1024) catch |err| {
        try output.printError("Error: Cannot read input file: {}\n", .{err});
        return;
    };
    defer allocator.free(input_data);

    if (verbose) try stdout.print("Encrypting...   ", .{});

    // Encrypt
    const encrypted = try encryptor.xorEncrypt(allocator, input_data, key);
    defer allocator.free(encrypted);

    if (verbose) try stdout.print("OK\nPacking...      ", .{});

    // Pack
    const packed_binary = try packer.packStub(allocator, bin_type, encrypted, key);
    defer allocator.free(packed_binary);

    if (verbose) try stdout.print("OK\nWriting...      ", .{});

    // Write output
    const output_file_handle = std.fs.cwd().createFile(output_path, .{}) catch |err| {
        try output.printError("Error: Cannot create output file '{s}': {}\n", .{ output_path, err });
        return;
    };
    defer output_file_handle.close();

    try output_file_handle.writeAll(packed_binary);

    // Set executable permissions on the file handle
    try output_file_handle.chmod(0o755);

    if (verbose) try stdout.print("OK\n\n", .{});

    // Summary - Fixed the format specifier
    try output.printResult(packed_binary.len, input_data.len, key, file_type, output_path);

    if (!verbose) {
        try stdout.print("Packed 1 file.\n", .{});
    }
}
