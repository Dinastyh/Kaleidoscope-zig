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
pub fn parseParenthesis(self: *Self) ParserError!*AstExpr {
    const expr = try parseExpression(self);
    errdefer expr.destroy(self.allocator);

    const next_token = try self.lexer.getNextToken();
    if (next_token != .parenthesis) return error.InvalidToken;
    if (next_token.parenthesis != .left) return error.InvalidToken;
    return expr;
}
