const std = @import("std");
const Value = @import("ast.zig").Value;

pub const Environment = struct {
    values: std.StringHashMap(Value),
    enclosing: ?*Environment,

    pub fn init(allocator: std.mem.Allocator, enclosing: ?*Environment) Environment {
        return .{ .values = .init(allocator), .enclosing = enclosing };
    }

    pub fn define(self: *Environment, name: []const u8, value: Value) !void {
        try self.values.put(name, value);
    }

    pub fn get(self: *Environment, name: []const u8) !Value {
        if (self.values.get(name)) |value| {
            return value;
        }
        if (self.enclosing) |enc| {
            return enc.get(name);
        }
        return error.UndefinedVariable;
    }

    pub fn assign(self: *Environment, name: []const u8, value: Value) !void {
        if (self.values.contains(name)) {
            try self.values.put(name, value);
            return;
        }
        if (self.enclosing) |enc| {
            try enc.assign(name, value);
            return;
        }
        return error.UndefinedVariable;
    }
};
