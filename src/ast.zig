const std = @import("std");
const TokenType = @import("tokens.zig").TokenType;

pub const EvalError = error{
    DivisionByZero,
    UnsupportedOperator,
    TypeError,
    InvalidOperand,
};

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

fn expectNumbers(left: Value, right: Value) !struct { f64, f64 } {
    if (left != .Number or right != .Number) return error.TypeError;
    return .{ left.Number, right.Number };
}

fn expectNumber(val: Value) !f64 {
    if (val != .Number) return error.TypeError;
    return val.Number;
}

fn expectBool(val: Value) !bool {
    if (val != .Bool) return error.TypeError;
    return val.Bool;
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

// TODO: When parser is created it will own a ArenaAllocator to manage the pointers
// TODO: Move eval to eval.zig later
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

    pub fn evalExp(self: Node) !Value {
        switch (self.expr) {
            .literal => |value| {
                return value;
            },

            .unary => |u| {
                const operand_val = try u.operand.evalExp();
                return switch (u.operator) {
                    .Minus => {
                        const n = try expectNumber(operand_val);
                        return Value{ .Number = -n };
                    },

                    .Bang => {
                        const n = try expectBool(operand_val);
                        return Value{ .Bool = !n };
                    },

                    else => return error.UnsupportedOperator,
                };
            },

            .binary => |b| {
                const operand_left = try b.left.evalExp();
                const operand_right = try b.right.evalExp();
                return switch (b.operator) {
                    .Minus => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);

                        return Value{ .Number = left_num - right_num };
                    },

                    .Plus => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);

                        return Value{ .Number = left_num + right_num };
                    },

                    .Star => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);
                        if (left_num == 0 or right_num == 0) return Value{ .Number = 0 };

                        return Value{ .Number = left_num * right_num };
                    },

                    .Power => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);
                        if (right_num == 0) return Value{ .Number = 1 };
                        const res = std.math.pow(f64, left_num, right_num);

                        return Value{ .Number = res };
                    },

                    .Slash => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);
                        if (right_num == 0) return error.DivisionByZero;
                        if (right_num == 1) return Value{ .Number = left_num };

                        return Value{ .Number = (left_num / right_num) };
                    },

                    .Greater => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);
                        return Value{ .Bool = left_num > right_num };
                    },

                    .GreaterEqual => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);
                        return Value{ .Bool = left_num >= right_num };
                    },

                    .Less => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);
                        return Value{ .Bool = left_num < right_num };
                    },

                    .LessEqual => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);
                        return Value{ .Bool = left_num <= right_num };
                    },

                    .EqualEqual => {
                        if (std.meta.activeTag(operand_left) != std.meta.activeTag(operand_right)) return error.TypeError;
                        return Value{ .Bool = std.meta.eql(operand_left, operand_right) };
                    },

                    .NotEqual => {
                        if (std.meta.activeTag(operand_left) != std.meta.activeTag(operand_right)) return error.TypeError;
                        return Value{ .Bool = !std.meta.eql(operand_left, operand_right) };
                    },

                    else => return error.UnsupportedOperator,
                };
            },
        }
    }
};
