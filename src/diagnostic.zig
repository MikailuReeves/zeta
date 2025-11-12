const std = @import("std");

// TODO: Fix formatting of printing
// TODO: Add better error reporting for different types of errors.
// TODO: Add errors to error array then print them all at the end.
pub fn reportError(source: []const u8, line: usize, column: usize, message: []const u8) !void {
    var buf: [512]u8 = undefined;
    var writer_obj = std.fs.File.stderr().writer(&buf);
    const w = &writer_obj.interface;

    // Print header
    try w.print("\x1b[31merror:\x1b[0m {s}\n", .{message});
    try w.print("  --> line {d}, column {d}\n", .{ line, column });
    try w.print("   |\n", .{});

    // Extract the relevant line text
    var tokenizer = std.mem.tokenizeScalar(u8, source, '\n');
    var i: usize = 1;
    var line_text: ?[]const u8 = null;
    while (tokenizer.next()) |t| : (i += 1) {
        if (i == line) {
            line_text = t;
            break;
        }
    }

    if (line_text) |lt| {
        try w.print("{d: >3} | {s}\n", .{ line, lt });
        try w.print("    | ", .{});
        // underline at column (basic caret)
        var j: usize = 1;
        while (j < column) : (j += 1) {
            try w.print(" ", .{});
        }
        try w.print("^\n", .{});
    } else {
        try w.print("    (line not found in source)\n", .{});
    }

    try w.flush();
}
