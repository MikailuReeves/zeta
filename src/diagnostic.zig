const std = @import("std");

pub const Diagnostic = struct {
    allocator: std.mem.Allocator,
    source_path: []const u8,
    source: []const u8,

    pub fn init(allocator: std.mem.Allocator, source_path: []const u8, source: []const u8) Diagnostic {
        return .{
            .allocator = allocator,
            .source_path = source_path,
            .source = source,
        };
    }

    fn getLine(self: *Diagnostic, line: usize) []const u8 {
        var it = std.mem.splitAny(u8, self.source, "\n");
        var current: usize = 1;
        while (it.next()) |chunk| {
            if (current == line) return chunk;
            current += 1;
        }
        return "";
    }

    pub fn report(self: *Diagnostic, err: anytype) !void {
        var err_buf: [256]u8 = undefined;
        var err_writer_buf = std.fs.File.stderr().writer(&err_buf);
        const stderr = &err_writer_buf.interface;

        const abs = try std.fs.cwd().realpathAlloc(self.allocator, self.source_path);
        defer self.allocator.free(abs);

        const label = try std.fmt.allocPrint(
            self.allocator,
            "{s}:{d}:{d}",
            .{ self.source_path, err.line, err.column },
        );
        defer self.allocator.free(label);

        const link = try std.fmt.allocPrint(
            self.allocator,
            "\x1b]8;;file:///{s}\x1b\\{s}\x1b]8;;\x1b\\",
            .{ abs, label },
        );
        defer self.allocator.free(link);

        // Header
        try stderr.print("\x1b[31mError:\x1b[0m {s}\n", .{@tagName(err.kind)});
        try stderr.print("    at {s}\n\n", .{link});

        // Context
        const start_line = if (err.line > 1) err.line - 1 else err.line;
        const end_line = err.line + 1;

        var it = std.mem.splitAny(u8, self.source, "\n");
        var current: usize = 1;

        while (it.next()) |chunk| {
            if (current >= start_line and current <= end_line) {
                try stderr.print(" {d: >4} | {s}\n", .{ current, chunk });

                if (current == err.line) {
                    try stderr.print("      | ", .{});
                    var i: usize = 0;
                    while (i < err.column - 1) : (i += 1) {
                        try stderr.writeByte(' ');
                    }
                    try stderr.print("\x1b[31m^\x1b[0m\n", .{});
                }
            }
            current += 1;
        }

        try stderr.print("\n", .{});
        try stderr.flush();
    }
};
