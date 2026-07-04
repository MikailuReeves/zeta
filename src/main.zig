const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const Diagnostic = @import("diagnostic.zig").Diagnostic;
const Parser = @import("parser.zig").Parser;
const Interpreter = @import("interpreter.zig").Interpreter;
const Ast = @import("ast.zig");

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
    std.debug.print("=== Source ===\n{s}\n", .{source_buffer});

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

    std.debug.print("=== Tokens ===\n", .{});
    for (tokens) |tok| {
        if (tok.lexeme.len > 0) {
            std.debug.print("  {s: <16} \"{s}\"\n", .{ @tagName(tok.kind), tok.lexeme });
        } else {
            std.debug.print("  {s}\n", .{@tagName(tok.kind)});
        }
    }

    // --- Parser ---
    var parser = Parser{
        .tokens = tokens,
        .current = 0,
        .allocator = allocator,
    };

    const declarations = parser.parse() catch |err| {
        std.debug.print("Parse error", .{});
        if (parser.last_error_message) |msg| {
            std.debug.print(": {s}", .{msg});
        }
        std.debug.print("\n", .{});
        return err;
    };

    std.debug.print("\n=== AST ===\n", .{});
    for (declarations) |decl| {
        Ast.prettyPrintDecl(decl, allocator, 0) catch {};
    }

    // --- Interpreter ---
    std.debug.print("\n=== Output ===\n", .{});
    var interpreter = Interpreter.init(allocator);
    interpreter.interpret(declarations) catch |err| {
        std.debug.print("Runtime error: {s}\n", .{@errorName(err)});
        return err;
    };
}
