const std = @import("std");
const String = @import("libs/strings.zig");

const ascci = std.ascii;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Reader = std.io.anyreader;

const Self = @This();

allocator: Allocator,
arena: ArenaAllocator,
reader: Reader,
buffer: [1024]u8 = [_]u8{0} ** 1024,
data: []u8 = undefined,
oef: bool = false,
not_filled: bool = true,

pub const BinaryOperator = enum(u8) {
    addition = '+',
    substraction = '-',
    multiplication = '*',
    division = '/',
    modulus = '%',
};

pub const Token = union(enum) {
    eof: void,
    def: void,
    @"extern": void,
    identifer: String,
    number: f64,
    parenthesis: enum(u8) { right = '(', left = ')' },
    operator: BinaryOperator,
};

pub fn init(allocator: Allocator, reader: Reader) Reader.Error!Self {
    const arena = std.heap.ArenaAllocator.init(allocator);
    const self = Self{ .allocator = allocator, .arena = arena, .reader = reader };
    return self;
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

fn fillBuffer(self: *Self) Reader.Error!usize {
    const r_size = try self.reader.read(&self.buffer);
    self.data = self.buffer[0..r_size];
    if (r_size == 0) {
        self.oef = true;
    }
    return r_size;
}

fn trimLeft(self: *Self) void {
    var begin: usize = 0;
    while (begin < self.data.len and (self.data[begin] == ' ' or self.data[begin] == '\n')) : (begin += 1) {}
    self.data = self.data[begin..];
}

pub const GetNextTokenError = error{InvalidToken} || Reader.Error || Allocator.Error || String.AppendError;

pub fn getNextToken(self: *Self) GetNextTokenError!Token {
    if (self.not_filled) {
        self.not_filled = false;
        _ = try self.fillBuffer();
    }

    if (self.oef and self.data.len == 0) return Token{ .eof = {} };
    while (true) {
        self.trimLeft();
        if (self.data.len != 0) break;
        if (try self.fillBuffer() == 0) break;
    }

    // Comment case
    if (self.data[0] == '#') {
        while (true) {
            var index: usize = 1;
            while (index < self.data.len and self.data[index] != '\n') : (index += 1) {}
            if (index != self.data.len) {
                self.data = self.data[index..];
                break;
            }
            if (try self.fillBuffer() == 0) break;
        }
    }

    // Def, identifer and extern case
    if (ascci.isAlphabetic(self.data[0])) {
        var str = try String.init(self.arena.allocator());
        while (true) {
            var index: usize = 1;
            while (index < self.data.len and ascci.isAlphanumeric(self.data[index])) : (index += 1) {}
            try str.appendSlice(self.data[0..index]);

            if (index != self.data.len) {
                self.data = self.data[index..];
                break;
            }
            if (try self.fillBuffer() == 0) break;
        }
        if (str.compare("def")) {
            str.deinit();
            return Token{ .def = {} };
        } else if (str.compare("extern")) {
            str.deinit();
            return Token{ .@"extern" = {} };
        }
        return Token{ .identifer = str };
    }

    // Number case
    else if (ascci.isDigit(self.data[0])) {
        var str = try String.init(self.arena.allocator());
        defer str.deinit();
        while (true) {
            var index: usize = 1;
            var dot_found = false;
            while (index < self.data.len and (ascci.isDigit(self.data[index]) or self.data[index] == '.')) : (index += 1) {
                // Only one dot is allowed
                if (self.data[index] == '.') {
                    if (dot_found) break else dot_found = true;
                }
            }
            try str.appendSlice(self.data[0..index]);

            if (index != self.data.len) {
                self.data = self.data[index..];
                break;
            }

            if (try self.fillBuffer() == 0) break;
        }
        return Token{ .number = std.fmt.parseFloat(
            f64,
            str.getSlice(),
        ) catch unreachable };
    }

    switch (self.data[0]) {
        '(', ')' => |c| {
            self.data = self.data[1..];
            return Token{ .parenthesis = @enumFromInt(c) };
        },
        '+', '-', '*', '/', '%' => |c| {
            self.data = self.data[1..];
            return Token{ .operator = @enumFromInt(c) };
        },
        else => {},
    }

    return error.InvalidToken;
}

test "Parse oef" {
    const buffer = try std.fmt.allocPrint(std.testing.allocator, "", .{});
    defer std.testing.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    var lexer = try Self.init(std.testing.allocator, stream.reader().any());
    defer lexer.deinit();

    try std.testing.expect(try lexer.getNextToken() == Token.eof);
}

test "Parse def" {
    const buffer = try std.fmt.allocPrint(std.testing.allocator, "def", .{});
    defer std.testing.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    var lexer = try Self.init(std.testing.allocator, stream.reader().any());
    defer lexer.deinit();

    try std.testing.expect(try lexer.getNextToken() == Token.def);
}

test "Parse extern" {
    const buffer = try std.fmt.allocPrint(std.testing.allocator, "extern", .{});
    defer std.testing.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    var lexer = try Self.init(std.testing.allocator, stream.reader().any());
    defer lexer.deinit();

    try std.testing.expect(try lexer.getNextToken() == Token.@"extern");
}

test "Parse identifer" {
    const buffer = try std.fmt.allocPrint(std.testing.allocator, "aaaaa59e", .{});
    defer std.testing.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    var lexer = try Self.init(std.testing.allocator, stream.reader().any());
    defer lexer.deinit();

    const token = try lexer.getNextToken();
    try std.testing.expect(token == Token.identifer);
    try std.testing.expect(token.identifer.compare("aaaaa59e"));
}

test "Parse number" {
    const buffer = try std.fmt.allocPrint(std.testing.allocator, "7778.636", .{});
    defer std.testing.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    var lexer = try Self.init(std.testing.allocator, stream.reader().any());
    defer lexer.deinit();

    const token = try lexer.getNextToken();
    try std.testing.expect(token == Token.number);
    try std.testing.expect(token.number == 7778.636);
}

test "Parse operator" {
    const buffer = try std.fmt.allocPrint(std.testing.allocator, "+-*/%", .{});
    defer std.testing.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    var lexer = try Self.init(std.testing.allocator, stream.reader().any());
    defer lexer.deinit();

    var token = try lexer.getNextToken();
    try std.testing.expect(token == Token.operator);
    try std.testing.expect(token.operator == .addition);
    token = try lexer.getNextToken();
    try std.testing.expect(token == Token.operator);
    try std.testing.expect(token.operator == .substraction);
    token = try lexer.getNextToken();
    try std.testing.expect(token == Token.operator);
    try std.testing.expect(token.operator == .multiplication);
    token = try lexer.getNextToken();
    try std.testing.expect(token == Token.operator);
    try std.testing.expect(token.operator == .division);
    token = try lexer.getNextToken();
    try std.testing.expect(token == Token.operator);
    try std.testing.expect(token.operator == .modulus);
}

test "Parse parenthesis" {
    const buffer = try std.fmt.allocPrint(std.testing.allocator, "()", .{});
    defer std.testing.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    var lexer = try Self.init(std.testing.allocator, stream.reader().any());
    defer lexer.deinit();

    var token = try lexer.getNextToken();
    try std.testing.expect(token == Token.parenthesis);
    try std.testing.expect(token.parenthesis == .right);
    token = try lexer.getNextToken();
    try std.testing.expect(token == Token.parenthesis);
    try std.testing.expect(token.parenthesis == .left);
}

test "Parse def, identifer and oef" {
    const buffer = try std.fmt.allocPrint(std.testing.allocator, "def aaaa", .{});
    defer std.testing.allocator.free(buffer);
    var stream = std.io.fixedBufferStream(buffer);
    var lexer = try Self.init(std.testing.allocator, stream.reader().any());
    defer lexer.deinit();

    try std.testing.expect(try lexer.getNextToken() == Token.def);
    const token = try lexer.getNextToken();
    try std.testing.expect(token == Token.identifer);
    try std.testing.expect(token.identifer.compare("aaaa"));
    try std.testing.expect(try lexer.getNextToken() == Token.eof);
}
