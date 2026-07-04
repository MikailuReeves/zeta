pub const Lexer = @import("lexer.zig").Lexer;
pub const Parser = @import("parser.zig").Parser;
pub const Tokens = @import("tokens.zig").TokenType;
pub const Ast = @import("ast.zig");
pub const Interpreter = @import("interpreter.zig").Interpreter;

test {
    _ = @import("parser.zig");
    _ = @import("ast.zig");
    _ = @import("interpreter.zig");
}
