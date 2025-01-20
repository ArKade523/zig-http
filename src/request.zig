const std = @import("std");

const Connection = std.net.Server.Connection;
const Method = @import("method.zig").Method;

pub fn read_request(conn: Connection, buffer: []u8) !void {
    const reader = conn.stream.reader();
    _ = try reader.read(buffer);
}

pub fn parse_request(buffer: []const u8) !Request {
    var iterator = std.mem.tokenize(u8, buffer, " ");
    const method_text = iterator.next() orelse return error.InvalidRequest;
    const uri = iterator.next() orelse return error.InvalidRequest;
    const version = iterator.next() orelse return error.InvalidRequest;

    if (Method.is_supported(method_text) == false) {
        return error.InvalidRequest;
    }
    const method = try Method.init(method_text);

    return Request{ .method = method, .uri = uri, .version = version };
}

const Request = struct {
    method: Method,
    version: []const u8,
    uri: []const u8,
    pub fn init(method: Method, version: []const u8, uri: []const u8) Request {
        return Request{
            .method = method,
            .version = version,
            .uri = uri,
        };
    }
};
