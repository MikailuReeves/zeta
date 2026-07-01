const std = @import("std");
const TokenType = @import("tokens.zig").TokenType;

const EvalError = error{
    DivisionByZero,
    UnsupportedOperator,
    TypeError,
    InvalidOperand,
};

const Value = union(enum) {
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

// TODO: When parser is created it will own a ArenaAllocator to manage the pointers
// TODO: Pretty printing the AST
pub const Node = struct {
    expr: Expr,
    line: usize,
    column: usize,

    pub fn evalExp(self: Node) !Value {
        switch (self.expr) {
            .literal => |value| {
                return value;
            },
            .unary => |u| {
                const operand_val = try u.operand.evalExp();
                return switch (u.operator) {
                    .Minus => {
                        switch (operand_val) {
                            .Number => |n| return Value{ .Number = -n },
                            else => return error.TypeError,
                        }
                    },
                    .Bang => {},
                    else => return error.UnsupportedOperator,
                };
            },
            .binary => |b| {
                const operand_left = try b.left.evalExp();
                const operand_right = try b.right.evalExp();
                return switch (b.operator) {
                    .Minus => operand_left - operand_right,
                    .Plus => operand_left + operand_right,
                    .Star => operand_left * operand_right,
                    .Power => {
                        if (operand_left != .Number or operand_right != .Number) return error.TypeError;
                        if (operand_right.Number == 0) return Value{ .Number = 1 }; // short circuit

                        const base = operand_left.Number;
                        const exponent = operand_right.Number;

                        const res = std.math.pow(f64, base, exponent);

                        return Value{ .Number = res };
                    },

                    .Slash => if (operand_right == 0) return error.DivisionByZero else operand_left / operand_right, // TODO: more short circuiting
                    else => return error.UnsupportedOperator,
                };
            },
        }
    }
};
