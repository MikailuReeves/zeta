const std = @import("std");
const TokenType = @import("tokens.zig").TokenType;
const Token = @import("lexer.zig").Token;

pub const Value = union(enum) {
    Number: f64,
    Bool: bool,
    String: []const u8,
    Null: void,
};

pub const Expr = union(enum) {
    literal: Value,
    unary: struct { operator: TokenType, operand: *const Node },
    binary: struct { left: *const Node, operator: TokenType, right: *const Node },
    identifier: []const u8,
    assign: struct { name: []const u8, value: *const Node },
};

pub const Decl = union(enum) {
    expr_statement: Node,
    print_statement: Node,
    var_statement: VarStatement,
    block: []Decl,
};

const VarStatement = struct {
    name: []const u8,
    var_expression: ?Node,
};

pub fn prettyPrintDecl(decl: Decl, allocator: std.mem.Allocator, depth: usize) !void {
    const indent = try allocator.alloc(u8, depth * 2);
    @memset(indent, ' ');

    switch (decl) {
        .expr_statement => |node| {
            const expr_str = try node.prettyPrint(allocator);
            std.debug.print("{s}ExprStmt: {s}\n", .{ indent, expr_str });
        },
        .print_statement => |node| {
            const expr_str = try node.prettyPrint(allocator);
            std.debug.print("{s}PrintStmt: {s}\n", .{ indent, expr_str });
        },
        .var_statement => |v| {
            if (v.var_expression) |expr| {
                const expr_str = try expr.prettyPrint(allocator);
                std.debug.print("{s}VarDecl: {s} = {s}\n", .{ indent, v.name, expr_str });
            } else {
                std.debug.print("{s}VarDecl: {s}\n", .{ indent, v.name });
            }
        },
        .block => |decls| {
            std.debug.print("{s}Block:\n", .{indent});
            for (decls) |d| {
                try prettyPrintDecl(d, allocator, depth + 1);
            }
        },
    }
}

fn opStr(op: TokenType) []const u8 {
    return switch (op) {
        .Plus => "+",
        .Minus => "-",
        .Star => "*",
        .Slash => "/",
        .Power => "**",
        .Bang => "!",
        .Greater => ">",
        .GreaterEqual => ">=",
        .Less => "<",
        .LessEqual => "<=",
        .EqualEqual => "==",
        .NotEqual => "!=",
        else => "?",
    };
}

fn ppValue(allocator: std.mem.Allocator, val: Value) ![]const u8 {
    return switch (val) {
        .Number => |n| try std.fmt.allocPrint(allocator, "{d}", .{n}),
        .Bool => |b| try std.fmt.allocPrint(allocator, "{}", .{b}),
        .String => |s| try std.fmt.allocPrint(allocator, "\"{s}\"", .{s}),
        .Null => try std.fmt.allocPrint(allocator, "null", .{}),
    };
}

pub const Node = struct {
    expr: Expr,
    line: usize,
    column: usize,

    pub fn prettyPrint(self: Node, allocator: std.mem.Allocator) ![]const u8 {
        switch (self.expr) {
            .literal => |value| return ppValue(allocator, value),
            .unary => |u| {
                const operand_str = try u.operand.prettyPrint(allocator);
                return std.fmt.allocPrint(allocator, "({s} {s})", .{ opStr(u.operator), operand_str });
            },
            .binary => |b| {
                const left_str = try b.left.prettyPrint(allocator);
                const right_str = try b.right.prettyPrint(allocator);
                return std.fmt.allocPrint(allocator, "({s} {s} {s})", .{ opStr(b.operator), left_str, right_str });
            },
            .identifier => |name| return std.fmt.allocPrint(allocator, "{s}", .{name}),
            .assign => |a| {
                const val_str = try a.value.prettyPrint(allocator);
                return std.fmt.allocPrint(allocator, "(= {s} {s})", .{ a.name, val_str });
            },
        }
    }
};
