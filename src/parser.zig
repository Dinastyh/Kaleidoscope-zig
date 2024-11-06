const std = @import("std");
const String = @import("libs/strings.zig");
const Lexer = @import("lexer.zig");
const ast = @import("ast.zig");

const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;
const Reader = std.io.AnyReader;

const AstExpr = ast.AstExpr;
const AstPrototype = ast.AstPrototype;
const AstFunction = ast.AstFunction;

const StringList = std.ArrayList(String);
const ArgList = std.ArrayList(*AstExpr);

const Token = Lexer.Token;
const Self = @This();

lexer: Lexer,
allocator: Allocator,
arena: Arena,

const ParserError = error{
    InvalidExpression,
} || Lexer.GetNextTokenError || Allocator.Error;

pub fn init(allocator: Allocator, reader: Reader) ParserError!Self {
    return Self{ .allocator = allocator, .arena = Arena.init(allocator), .lexer = try Lexer.init(allocator, reader) };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

fn parseNumber(self: *Self) ParserError!*AstExpr {
    return try AstExpr.alloc(.{ .number = (try self.lexer.getCurrentToken()).number }, self.arena.allocator());
}
fn parseExpression(self: *Self) ParserError!*AstExpr {
    const allocated_LHS = try self.parsePrimary();
    errdefer allocated_LHS.destroy(self.arena.allocator());

    const token = try self.lexer.getNextToken();
    if (token != .operator) return allocated_LHS;
    return try self.parseBinOpRHS(0, allocated_LHS);
}

pub fn parseIdentifier(self: *Self) ParserError!*AstExpr {
    const idName = try self.lexer.getCurrentToken();
    var next_token = try self.lexer.getNextToken();
    if (next_token != .parenthesis or next_token.parenthesis == .right)
        return try AstExpr.alloc(.{ .variable = idName.identifer }, self.allocator);

    next_token = try self.lexer.getNextToken();
    var args = ArgList.init(self.arena.allocator());
    errdefer for (args.items) |i| i.destroy(self.allocator);

    while (true) : (next_token = try self.lexer.getNextToken()) {
        try args.append(try self.parseExpression());
        next_token = try self.lexer.getNextToken();
        if (next_token == .parenthesis and next_token.parenthesis == .left) break;
        if (next_token != .comma) return error.InvalidExpression;
    }

    return try AstExpr.alloc(.{ .call = .{ .args = args, .callee = idName.identifer } }, self.arena.allocator());
}

pub fn parsePrimary(self: *Self) ParserError!*AstExpr {
    const token = try self.lexer.getCurrentToken();
    return switch (token) {
        .identifer => try self.parseIdentifier(),
        .number => try self.parseNumber(),
        .parenthesis => if (token.parenthesis != .right) error.InvalidExpression else try self.parseParenthesis(),
        else => error.InvalidExpression,
    };
}

pub fn parseParenthesis(self: *Self) ParserError!*AstExpr {
    const expr = try parseExpression(self);
    errdefer expr.destroy(self.allocator);

    const next_token = try self.lexer.getNextToken();
    if (next_token != .parenthesis) return error.InvalidToken;
    if (next_token.parenthesis != .left) return error.InvalidToken;
    return expr;
}
