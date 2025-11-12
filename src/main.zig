const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const source = "//comment chat \n //another comment brev \n +";
    var lexer = try Lexer.init(allocator, source);
    defer lexer.deinit();

    const tokens = try lexer.scanTokens();

    for (tokens) |token| {
        std.debug.print("Token: {s} | Lexeme: \"{s}\" | Line: {d} | Column: {d}\n", .{ @tagName(token.kind), token.lexeme, token.line, token.column });
    }
}
