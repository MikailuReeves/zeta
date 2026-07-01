pub const TokenType = enum {
    // Operators
    Star,
    Slash,
    Plus,
    Minus,
    Bang,
    Power,
    Equal,

    // Comparison
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    EqualEqual,
    NotEqual,

    // Delimiters
    Comma,
    Semicolon,
    Dot,

    // Groups
    LBrace,
    RBrace,
    LParen,
    RParen,

    // Keywords
    Else,
    Fun,
    If,
    Let,
    Return,
    True,
    False,
    For,
    While,
    Null,
    Var,
    Print,
    Or,
    And,

    // Special
    Eof,

    // Literals
    Identifier,
    Number,
    String,
};
