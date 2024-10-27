const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const Self = @This();

buffer: []u8,
allocator: Allocator,
len: usize = 0,

pub fn init(allocator: Allocator) Allocator.Error!Self {
    return initWithSize(allocator, 1024);
}

pub fn initWithSize(allocator: Allocator, size: usize) Allocator.Error!Self {
    const buffer = try allocator.alloc(u8, size);
    return Self{ .buffer = buffer, .allocator = allocator };
}

const AppendError = error{
    ResizeFailed,
};

pub fn appendSlice(self: *Self, slice: []const u8) AppendError!void {
    if (slice.len + self.len >= self.buffer.len) {
        if (!self.allocator.resize(self.buffer, self.buffer.len + 1024)) {
            return error.ResizeFailed;
        }
    }
    @memcpy(self.buffer[self.len .. self.len + slice.len], slice);
    self.len += slice.len;
}

pub fn appendChar(self: *Self, char: u8) AppendError!void {
    if (self.len + 1 >= self.buffer.len) {
        if (!self.allocator.resize(self.buffer, self.buffer.len + 1024)) {
            return error.ResizeFailed;
        }
    }
    self.buffer[self.len] = char;
    self.len += 1;
}

pub fn compare(self: *const Self, str: []const u8) bool {
    return mem.eql(u8, self.getSlice(), str);
}

pub fn getSlice(self: *const Self) []u8 {
    return self.buffer[0..self.len];
}

pub fn deinit(self: *const Self) void {
    self.allocator.free(self.buffer);
}

test "Append Slice" {
    var str = try init(std.testing.allocator);
    defer str.deinit();
    try str.appendSlice("Test");
    try std.testing.expectEqualSlices(u8, str.getSlice(), "Test");
}

test "Append Multiple Slice" {
    var str = try init(std.testing.allocator);
    defer str.deinit();
    try str.appendSlice("Test");
    try str.appendSlice("Multiple");
    try std.testing.expectEqualSlices(u8, str.getSlice(), "TestMultiple");
}

test "Append Char" {
    var str = try init(std.testing.allocator);
    defer str.deinit();
    try str.appendChar('c');
    try std.testing.expectEqualSlices(u8, str.getSlice(), "c");
}

test "Append Multiple Char" {
    var str = try init(std.testing.allocator);
    defer str.deinit();
    try str.appendChar('c');
    try str.appendChar('a');
    try std.testing.expectEqualSlices(u8, str.getSlice(), "ca");
}

test "Append Multiple Slice and char" {
    var str = try init(std.testing.allocator);
    defer str.deinit();
    try str.appendSlice("Test");
    try str.appendSlice("Multiple");
    try str.appendChar('c');
    try std.testing.expectEqualSlices(u8, str.getSlice(), "TestMultiplec");
}

test "Append Multiple Slice and char and compare true" {
    var str = try init(std.testing.allocator);
    defer str.deinit();
    try str.appendSlice("Test");
    try str.appendSlice("Multiple");
    try str.appendChar('c');
    try std.testing.expect(str.compare("TestMultiplec"));
}

test "Append Multiple Slice and char and compare false" {
    var str = try init(std.testing.allocator);
    defer str.deinit();
    try str.appendSlice("Test");
    try str.appendSlice("Multiple");
    try str.appendChar('c');
    try std.testing.expect(!str.compare("TestMultiple"));
}
