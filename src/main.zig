const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const Diagnostic = @import("diagnostic.zig").Diagnostic;
const Ast = @import("ast.zig");
const Node = Ast.Node;
const Expr = Ast.Expr;
const Value = Ast.Value;

fn printValue(val: Value) void {
    switch (val) {
        .Number => |n| std.debug.print("{d}", .{n}),
        .Bool => |b| std.debug.print("{}", .{b}),
        .String => |s| std.debug.print("\"{s}\"", .{s}),
        .Null => std.debug.print("null", .{}),
    }
}

fn runExpr(label: []const u8, allocator: std.mem.Allocator, node: Node) void {
    _ = allocator;
    std.debug.print("{s} => ", .{label});
    if (node.evalExp()) |val| {
        printValue(val);
        std.debug.print("\n", .{});
    } else |err| {
        std.debug.print("ERROR: {s}\n", .{@errorName(err)});
    }
}

fn createNode(allocator: std.mem.Allocator, expr: Expr) *const Node {
    const ptr = allocator.create(Node) catch @panic("alloc failed");
    ptr.* = .{ .expr = expr, .line = 1, .column = 1 };
    return ptr;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = std.heap.page_allocator;

    // --- AST playground ---
    std.debug.print("\n=== AST Evaluation ===\n\n", .{});

    // 1 + 2
    const one = createNode(allocator, .{ .literal = .{ .Number = 1 } });
    const two = createNode(allocator, .{ .literal = .{ .Number = 2 } });
    runExpr("1 + 2", allocator, .{ .expr = .{ .binary = .{ .left = one, .operator = .Plus, .right = two } }, .line = 1, .column = 1 });

    // -(5)
    const five = createNode(allocator, .{ .literal = .{ .Number = 5 } });
    runExpr("-(5)", allocator, .{ .expr = .{ .unary = .{ .operator = .Minus, .operand = five } }, .line = 1, .column = 1 });

    // !true
    const t = createNode(allocator, .{ .literal = .{ .Bool = true } });
    runExpr("!true", allocator, .{ .expr = .{ .unary = .{ .operator = .Bang, .operand = t } }, .line = 1, .column = 1 });

    // 10 / 0 (error)
    const ten = createNode(allocator, .{ .literal = .{ .Number = 10 } });
    const zero = createNode(allocator, .{ .literal = .{ .Number = 0 } });
    runExpr("10 / 0", allocator, .{ .expr = .{ .binary = .{ .left = ten, .operator = .Slash, .right = zero } }, .line = 1, .column = 1 });

    // -(true) (type error)
    const t2 = createNode(allocator, .{ .literal = .{ .Bool = true } });
    runExpr("-(true)", allocator, .{ .expr = .{ .unary = .{ .operator = .Minus, .operand = t2 } }, .line = 1, .column = 1 });

    // 2 ** 8
    const base = createNode(allocator, .{ .literal = .{ .Number = 2 } });
    const exp = createNode(allocator, .{ .literal = .{ .Number = 8 } });
    runExpr("2 ** 8", allocator, .{ .expr = .{ .binary = .{ .left = base, .operator = .Power, .right = exp } }, .line = 1, .column = 1 });

    // "hello" + 1 (type error)
    const hello = createNode(allocator, .{ .literal = .{ .String = "hello" } });
    const n1 = createNode(allocator, .{ .literal = .{ .Number = 1 } });
    runExpr("\"hello\" + 1", allocator, .{ .expr = .{ .binary = .{ .left = hello, .operator = .Plus, .right = n1 } }, .line = 1, .column = 1 });

    const a = createNode(allocator, .{ .literal = .{ .Number = 5 } });
    const b = createNode(allocator, .{ .literal = .{ .Number = 5 } });
    runExpr("5 == 5", allocator, .{ .expr = .{ .binary = .{ .left = a, .operator = .EqualEqual, .right = b } }, .line = 1, .column = 1 });

    const a2 = createNode(allocator, .{ .literal = .{ .Number = 5 } });
    const b2 = createNode(allocator, .{ .literal = .{ .Number = 3 } });
    runExpr("5 == 3", allocator, .{ .expr = .{ .binary = .{ .left = a2, .operator = .EqualEqual, .right = b2 } }, .line = 1, .column = 1 });

    const boolval = createNode(allocator, .{ .literal = .{ .Bool = true } });
    const num = createNode(allocator, .{ .literal = .{ .Number = 5 } });
    runExpr("true == 5", allocator, .{ .expr = .{ .binary = .{ .left = boolval, .operator = .EqualEqual, .right = num } }, .line = 1, .column = 1 });

    const n2 = createNode(allocator, .{ .literal = .{ .Number = 5 } });
    const n3 = createNode(allocator, .{ .literal = .{ .Number = 5 } });
    runExpr("5 != 5", allocator, .{ .expr = .{ .binary = .{ .left = n2, .operator = .NotEqual, .right = n3 } }, .line = 1, .column = 1 });

    // --- Lexer ---
    std.debug.print("\n=== Lexer ===\n\n", .{});

    const source_path = "source.txt";

    const source_buffer = try std.Io.Dir.readFileAlloc(
        std.Io.Dir.cwd(),
        io,
        source_path,
        allocator,
        .unlimited,
    );

    var lexer = try Lexer.init(allocator, source_buffer);
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();

    for (tokens) |token| {
        std.debug.print("Token: {s} | Lexeme: \"{s}\" | Line: {d} | Column: {d}\n", .{
            @tagName(token.kind), token.lexeme, token.line, token.column,
        });
    }

    var diag = Diagnostic.init(allocator, source_path, source_buffer);

    for (lexer.errors.items) |err| {
        try diag.report(err);
    }
}
