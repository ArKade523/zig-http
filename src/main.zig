const std = @import("std");
const SocketConf = @import("config.zig");
const Request = @import("request.zig");
const Response = @import("response.zig");
const Method = @import("method.zig").Method;
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    // var args = std.process.args();
    // _ = args.skip();

    const socket = try SocketConf.Socket.init(.{ 127, 0, 0, 1 }, 8000);
    std.log.info("Server Address: {any}\n", .{socket._address});
    const allocator = std.heap.page_allocator;

    var server = try socket._address.listen(.{});
    defer server.deinit();

    while (true) {
        const connection = try server.accept();
        var buffer: [1024]u8 = undefined;
        for (0..buffer.len) |i| {
            buffer[i] = 0;
        }

        try Request.read_request(connection, buffer[0..buffer.len]);
        const request = Request.parse_request(buffer[0..buffer.len]) catch |err| {
            std.log.err("Error parsing request: {s}\n", .{@errorName(err)});
            try Response.send_404(connection);
            continue;
        };

        std.log.info("Received request to uri: {s}", .{request.uri});

        const files: [][]u8 = try get_files_in_directory(allocator, "./html");

        if (request.method == Method.GET) {
            if (try contains_file(allocator, files, request.uri)) {
                try Response.send_200(connection, request.uri);
            } else {
                try Response.send_404(connection);
            }
        }
    }
}

fn contains_file(allocator: std.mem.Allocator, files: [][]u8, uri: []const u8) !bool {
    var normalized_uri: []const u8 = uri;
    if (uri[0] != '/') {
        normalized_uri = try std.fmt.allocPrint(allocator, "/{s}", .{uri});
    }

    for (files) |file| {
        if (std.mem.eql(u8, file, normalized_uri)) {
            return true;
        }
    }
    return false;
}

fn get_files_in_directory(allocator: std.mem.Allocator, dir_path: []const u8) ![][]u8 {
    var dir = try std.fs.cwd().openDir(dir_path, .{});
    defer dir.close();

    var files = std.ArrayList([]u8).init(allocator);
    defer files.deinit(); // Ensure memory is freed if the function exits early.

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (true) {
        const entry = try walker.next();
        if (entry == null) break;

        if (entry.?.kind == std.fs.File.Kind.directory) continue;

        // Allocate memory for the basename and append to the list
        const filepath = try allocator.alloc(u8, entry.?.path.len + 1);
        filepath[0] = '/';
        std.mem.copyForwards(u8, filepath[1..], entry.?.path);
        try files.append(filepath);
    }

    return files.toOwnedSlice();
}
