const std = @import("std");

pub fn xor_encrypt(allocator: std.mem.Allocator, input_bin: []const u8, key: u8) ![]u8 {
    const encrypted = try allocator.alloc(u8, input_bin.len);
    for (input_bin, 0..) |byte, i| {
        encrypted[i] = byte ^ key;
    }
    return encrypted;
}
