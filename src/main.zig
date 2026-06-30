const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const Diagnostic = @import("diagnostic.zig").Diagnostic;

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
