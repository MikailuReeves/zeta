const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const source_path = "source.txt";
    const max_size = 10 * 1024 * 1024; // 10 mb

    const source_buffer = try std.fs.cwd().readFileAlloc(allocator, source_path, max_size);

    var lexer = try Lexer.init(allocator, source_buffer);
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();

    for (tokens) |token| {
        std.debug.print("Token: {s} | Lexeme: \"{s}\" | Line: {d} | Column: {d}\n", .{ @tagName(token.kind), token.lexeme, token.line, token.column });
    }
}
