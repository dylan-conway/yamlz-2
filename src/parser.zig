const std = @import("std");

pub const Document = struct {
    // Placeholder for now
    data: []const u8,
};

pub fn parse(input: []const u8) !Document {
    _ = input; // Suppress unused parameter warning
    // For now, just return error to see all tests fail
    return error.NotImplemented;
}