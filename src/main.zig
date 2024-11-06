const std = @import("std");
const Parser = @import("parser.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var parser = try Parser.init(gpa.allocator(), std.io.getStdIn().reader().any());
    defer parser.deinit();

    try parser.runTopLevel();
}
