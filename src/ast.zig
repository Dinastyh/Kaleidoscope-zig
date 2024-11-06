const std = @import("std");
const Lexer = @import("lexer.zig");
const String = @import("libs/strings.zig");

const StringList = std.ArrayList(String);
const ArgList = std.ArrayList(*AstExpr);
const Allocator = std.mem.Allocator;

pub const AstExpr = union(enum) {
    const Self = @This();
    number: f64,
    variable: String,
    binary: struct {
        operator: Lexer.BinaryOperator,
        lhs: *AstExpr,
        rhs: *AstExpr,
    },
    call: struct {
        callee: String,
        args: ArgList,
    },

    pub fn alloc(self: Self, allocator: Allocator) Allocator.Error!*@This() {
        const ptr = try allocator.create(Self);
        ptr.* = self;
        return ptr;
    }

    pub fn destroy(self: *Self, allocator: Allocator) void {
        switch (self.*) {
            .variable => self.variable.deinit(),
            .binary => {
                self.binary.rhs.destroy(allocator);
                self.binary.lhs.destroy(allocator);
            },
            .call => {
                self.call.callee.deinit();
                for (self.call.args.items) |i| i.destroy(allocator);
            },
            else => {},
        }
        allocator.destroy(self);
    }
};

pub const AstPrototype = struct {
    name: String,
    args: StringList,
    pub fn destroy(self: *const @This()) void {
        self.name.deinit();
        for (self.args.items) |i| i.deinit();
    }
};

pub const AstFunction = struct {
    proto: AstPrototype,
    body: *AstExpr,
    pub fn destroy(self: *const @This(), allocator: Allocator) void {
        self.proto.destroy();
        self.body.destroy(allocator);
    }
};
