// zig fmt: off
const std = @import("std");
const Ast = @import("ast.zig");
const Decl = Ast.Decl;
const Node = Ast.Node;
const Value = Ast.Value;
const TokenType = @import("tokens.zig").TokenType;
const Environment = @import("environment.zig").Environment;

pub const EvalError = error{
    DivisionByZero,
    UndefinedVariable,
    UnsupportedOperator,
    TypeError,
    InvalidOperand,
    OutOfMemory,
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


pub const Interpreter = struct {
    environment: Environment,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Interpreter {
        return .{
            .environment = Environment.init(allocator, null),
            .allocator = allocator,
        };
    }

    pub fn executeBlock(self: *Interpreter, decls: []Decl) !void {
        const previous = try self.allocator.create(Environment);
        previous.* = self.environment;

        self.environment = Environment.init(self.allocator, previous);
        try self.interpret(decls);
        self.environment = previous.*;
    }

    pub fn interpret(self: *Interpreter, decls: []Decl) EvalError!void {
        for (decls) |decl| {
            switch (decl) {
                .expr_statement => |node| {
                    _ = try self.evalExp(node);
                },
                .print_statement => |node| {
                    const val = try self.evalExp(node);
                    switch (val) {
                        .Number => |n| std.debug.print("{d}\n", .{n}),
                        .Bool => |b| std.debug.print("{}\n", .{b}),
                        .String => |s| std.debug.print("{s}\n", .{s}),
                        .Null => std.debug.print("null\n", .{}),
                    }
                },
                .var_statement => |v| {
                    var value: Value = .Null;
                    if (v.var_expression) |expr| {
                        value = try self.evalExp(expr);
                    }
                    try self.environment.define(v.name, value);
                },
                .block => |decs| {
                    try self.executeBlock(decs);
                }
            }
        }
    }

    pub fn evalExp(self: *Interpreter, node: Node) EvalError!Value {
        switch (node.expr) {
            .literal => |value| {
                return value;
            },

            .identifier => |name| {
                return self.environment.get(name);
            },
            .assign => |a| {
                const value = try self.evalExp(a.value.*);
                try self.environment.assign(a.name, value);
                return value;
            },

            .unary => |u| {
                const operand_val = try self.evalExp(u.operand.*);
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
                const operand_left = try self.evalExp(b.left.*);
                const operand_right = try self.evalExp(b.right.*);
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

                    .Less => {
                        const left_num, const right_num = try expectNumbers(operand_left, operand_right);
                        return Value{ .Bool = left_num < right_num };
                    },

                    .EqualEqual => {
                        if (std.meta.activeTag(operand_left) != std.meta.activeTag(operand_right)) return error.TypeError;
                        return Value{ .Bool = std.meta.eql(operand_left, operand_right) };
                    },

                    else => return error.UnsupportedOperator,
                };
            },
        }
    }
};

test "interpreter compiles" {
    _ = &Interpreter.interpret;
    _ = &Interpreter.evalExp;
    _ = &expectBool;
    _ = &expectNumber;
    _ = &expectNumbers;
    _ = &Interpreter.interpret;
}
