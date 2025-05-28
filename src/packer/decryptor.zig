const std = @import("std");

///return the decrypted payload
pub fn xor_decrypt(allocator: std.mem.Allocator, encrypted_input_bin: []const u8, key: u8) ![]u8 {
    const decrypted = try allocator.alloc(u8, encrypted_input_bin.len);
    for (encrypted_input_bin, 0..) |byte, i| {
        decrypted[i] = byte ^ key;
    }
    return decrypted;
}
