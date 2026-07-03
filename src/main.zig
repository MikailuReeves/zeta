const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const Diagnostic = @import("diagnostic.zig").Diagnostic;
const Parser = @import("parser.zig").Parser;
const Ast = @import("ast.zig");
const Node = Ast.Node;
const Value = Ast.Value;
const eval = @import("eval.zig");

fn printValue(val: Value) void {
    switch (val) {
        .Number => |n| std.debug.print("{d}", .{n}),
        .Bool => |b| std.debug.print("{}", .{b}),
        .String => |s| std.debug.print("\"{s}\"", .{s}),
        .Null => std.debug.print("null", .{}),
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = std.heap.page_allocator;

    const source_path = "source.txt";

    const source_buffer = try std.Io.Dir.readFileAlloc(
        std.Io.Dir.cwd(),
        io,
        source_path,
        allocator,
        .unlimited,
    );

    // --- Lexer ---
    var lexer = try Lexer.init(allocator, source_buffer);
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();

    if (lexer.errors.items.len > 0) {
        var diag = Diagnostic.init(allocator, source_path, source_buffer);
        for (lexer.errors.items) |err| {
            try diag.report(err);
        }
        return;
    }

    // --- Parser ---
    var parser = Parser{
        .tokens = tokens,
        .current = 0,
        .allocator = allocator,
    };

    if (parser.parse()) |node| {
        if (node.prettyPrint(allocator)) |pp| {
            std.debug.print("AST: {s}\n", .{pp});
        } else |_| {
            std.debug.print("AST: <print error>\n", .{});
        }

        if (eval.evalExp(node)) |val| {
            std.debug.print("Result: ", .{});
            printValue(val);
            std.debug.print("\n", .{});
        } else |err| {
            std.debug.print("Eval ERROR: {s}\n", .{@errorName(err)});
        }
    } else {
        std.debug.print("Parse error", .{});
        if (parser.last_error_message) |msg| {
            std.debug.print(": {s}", .{msg});
        }
        std.debug.print("\n", .{});
    }
}
