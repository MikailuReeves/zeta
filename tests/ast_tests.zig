const std = @import("std");
const zeta = @import("zeta");

const Node = zeta.Ast.Node;
const Expr = zeta.Ast.Expr;
const Value = zeta.Ast.Value;
const TokenType = zeta.Tokens;
const Interpreter = zeta.Interpreter;

fn createNode(allocator: std.mem.Allocator, expr: Expr, line: usize, column: usize) !*const Node {
    const ptr = try allocator.create(Node);
    ptr.* = .{ .expr = expr, .line = line, .column = column };
    return ptr;
}

fn numNode(allocator: std.mem.Allocator, n: f64) !*const Node {
    return createNode(allocator, .{ .literal = .{ .Number = n } }, 1, 1);
}

fn boolNode(allocator: std.mem.Allocator, b: bool) !*const Node {
    return createNode(allocator, .{ .literal = .{ .Bool = b } }, 1, 1);
}

fn evalNode(node: Node) !Value {
    var interp = Interpreter.init(std.testing.allocator);
    return interp.evalExp(node);
}

// --- Literal tests ---

test "literal number evaluates to itself" {
    const node = Node{ .expr = .{ .literal = .{ .Number = 42.0 } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 42.0 }, result);
}

test "literal bool evaluates to itself" {
    const node = Node{ .expr = .{ .literal = .{ .Bool = true } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Bool = true }, result);
}

test "literal null evaluates to itself" {
    const node = Node{ .expr = .{ .literal = .{ .Null = {} } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Null = {} }, result);
}

// --- Unary tests ---

test "negate a number: -(5)" {
    const allocator = std.testing.allocator;
    const five = try numNode(allocator, 5.0);
    defer allocator.destroy(five);

    const node = Node{ .expr = .{ .unary = .{ .operator = .Minus, .operand = five } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = -5.0 }, result);
}

test "negate a bool is a type error" {
    const allocator = std.testing.allocator;
    const t = try boolNode(allocator, true);
    defer allocator.destroy(t);

    const node = Node{ .expr = .{ .unary = .{ .operator = .Minus, .operand = t } }, .line = 1, .column = 1 };
    try std.testing.expectError(error.TypeError, evalNode(node));
}

test "logical not: !true = false" {
    const allocator = std.testing.allocator;
    const t = try boolNode(allocator, true);
    defer allocator.destroy(t);

    const node = Node{ .expr = .{ .unary = .{ .operator = .Bang, .operand = t } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Bool = false }, result);
}

test "logical not on number is a type error" {
    const allocator = std.testing.allocator;
    const n = try numNode(allocator, 1.0);
    defer allocator.destroy(n);

    const node = Node{ .expr = .{ .unary = .{ .operator = .Bang, .operand = n } }, .line = 1, .column = 1 };
    try std.testing.expectError(error.TypeError, evalNode(node));
}

// --- Binary arithmetic tests ---

test "binary add: 1 + 2 = 3" {
    const allocator = std.testing.allocator;
    const one = try numNode(allocator, 1.0);
    defer allocator.destroy(one);
    const two = try numNode(allocator, 2.0);
    defer allocator.destroy(two);

    const node = Node{ .expr = .{ .binary = .{ .left = one, .operator = .Plus, .right = two } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 3.0 }, result);
}

test "binary subtract: 5 - 3 = 2" {
    const allocator = std.testing.allocator;
    const five = try numNode(allocator, 5.0);
    defer allocator.destroy(five);
    const three = try numNode(allocator, 3.0);
    defer allocator.destroy(three);

    const node = Node{ .expr = .{ .binary = .{ .left = five, .operator = .Minus, .right = three } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 2.0 }, result);
}

test "binary multiply: 3 * 4 = 12" {
    const allocator = std.testing.allocator;
    const three = try numNode(allocator, 3.0);
    defer allocator.destroy(three);
    const four = try numNode(allocator, 4.0);
    defer allocator.destroy(four);

    const node = Node{ .expr = .{ .binary = .{ .left = three, .operator = .Star, .right = four } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 12.0 }, result);
}

test "multiply by zero short circuits" {
    const allocator = std.testing.allocator;
    const five = try numNode(allocator, 5.0);
    defer allocator.destroy(five);
    const zero = try numNode(allocator, 0.0);
    defer allocator.destroy(zero);

    const node = Node{ .expr = .{ .binary = .{ .left = five, .operator = .Star, .right = zero } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 0.0 }, result);
}

test "valid division: 10 / 2 = 5" {
    const allocator = std.testing.allocator;
    const ten = try numNode(allocator, 10.0);
    defer allocator.destroy(ten);
    const two = try numNode(allocator, 2.0);
    defer allocator.destroy(two);

    const node = Node{ .expr = .{ .binary = .{ .left = ten, .operator = .Slash, .right = two } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 5.0 }, result);
}

test "division by one short circuits" {
    const allocator = std.testing.allocator;
    const seven = try numNode(allocator, 7.0);
    defer allocator.destroy(seven);
    const one = try numNode(allocator, 1.0);
    defer allocator.destroy(one);

    const node = Node{ .expr = .{ .binary = .{ .left = seven, .operator = .Slash, .right = one } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 7.0 }, result);
}

test "division by zero returns error" {
    const allocator = std.testing.allocator;
    const ten = try numNode(allocator, 10.0);
    defer allocator.destroy(ten);
    const zero = try numNode(allocator, 0.0);
    defer allocator.destroy(zero);

    const node = Node{ .expr = .{ .binary = .{ .left = ten, .operator = .Slash, .right = zero } }, .line = 1, .column = 1 };
    try std.testing.expectError(error.DivisionByZero, evalNode(node));
}

test "power: 2 ** 3 = 8" {
    const allocator = std.testing.allocator;
    const two = try numNode(allocator, 2.0);
    defer allocator.destroy(two);
    const three = try numNode(allocator, 3.0);
    defer allocator.destroy(three);

    const node = Node{ .expr = .{ .binary = .{ .left = two, .operator = .Power, .right = three } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 8.0 }, result);
}

test "power zero short circuits: 5 ** 0 = 1" {
    const allocator = std.testing.allocator;
    const five = try numNode(allocator, 5.0);
    defer allocator.destroy(five);
    const zero = try numNode(allocator, 0.0);
    defer allocator.destroy(zero);

    const node = Node{ .expr = .{ .binary = .{ .left = five, .operator = .Power, .right = zero } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 1.0 }, result);
}

// --- Type error tests ---

test "adding bool and number is a type error" {
    const allocator = std.testing.allocator;
    const t = try boolNode(allocator, true);
    defer allocator.destroy(t);
    const n = try numNode(allocator, 1.0);
    defer allocator.destroy(n);

    const node = Node{ .expr = .{ .binary = .{ .left = t, .operator = .Plus, .right = n } }, .line = 1, .column = 1 };
    try std.testing.expectError(error.TypeError, evalNode(node));
}

// --- Nested expression tests ---

test "nested: -(1 + 2) = -3" {
    const allocator = std.testing.allocator;
    const one = try numNode(allocator, 1.0);
    defer allocator.destroy(one);
    const two = try numNode(allocator, 2.0);
    defer allocator.destroy(two);

    const add = try createNode(allocator, .{ .binary = .{ .left = one, .operator = .Plus, .right = two } }, 1, 1);
    defer allocator.destroy(add);

    const node = Node{ .expr = .{ .unary = .{ .operator = .Minus, .operand = add } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = -3.0 }, result);
}

test "deeper nesting: (1 + 2) * (4 - 1) = 9" {
    const allocator = std.testing.allocator;
    const one = try numNode(allocator, 1.0);
    defer allocator.destroy(one);
    const two = try numNode(allocator, 2.0);
    defer allocator.destroy(two);
    const four = try numNode(allocator, 4.0);
    defer allocator.destroy(four);
    const one_b = try numNode(allocator, 1.0);
    defer allocator.destroy(one_b);

    const left = try createNode(allocator, .{ .binary = .{ .left = one, .operator = .Plus, .right = two } }, 1, 1);
    defer allocator.destroy(left);
    const right = try createNode(allocator, .{ .binary = .{ .left = four, .operator = .Minus, .right = one_b } }, 1, 1);
    defer allocator.destroy(right);

    const node = Node{ .expr = .{ .binary = .{ .left = left, .operator = .Star, .right = right } }, .line = 1, .column = 1 };
    const result = try evalNode(node);
    try std.testing.expectEqual(Value{ .Number = 9.0 }, result);
}
