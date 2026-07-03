const std = @import("std");
const TokenType = @import("tokens.zig").TokenType;

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
};

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
        }
    }
};
