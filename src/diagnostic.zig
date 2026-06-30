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
        const label = try std.fmt.allocPrint(
            self.allocator,
            "{s}:{d}:{d}",
            .{ self.source_path, err.line, err.column },
        );
        defer self.allocator.free(label);

        // Header
        std.debug.print("\x1b[31mError:\x1b[0m {s}\n", .{@tagName(err.kind)});
        std.debug.print("    at {s}\n\n", .{label});

        // Context
        const start_line = if (err.line > 1) err.line - 1 else err.line;
        const end_line = err.line + 1;

        var it = std.mem.splitAny(u8, self.source, "\n");
        var current: usize = 1;

        while (it.next()) |chunk| {
            if (current >= start_line and current <= end_line) {
                std.debug.print(" {d: >4} | {s}\n", .{ current, chunk });
                if (current == err.line) {
                    std.debug.print("      | ", .{});
                    var i: usize = 0;
                    while (i < err.column - 1) : (i += 1) {
                        std.debug.print(" ", .{});
                    }
                    std.debug.print("\x1b[31m^\x1b[0m\n", .{});
                }
            }
            current += 1;
        }
        std.debug.print("\n", .{});
    }
};
