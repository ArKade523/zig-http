const std = @import("std");
const Map = std.static_string_map.StaticStringMap;
const Connection = std.net.Server.Connection;

pub fn send_200(conn: Connection, uri: []const u8) !void {
    const fs = std.fs;
    const allocator = std.heap.page_allocator;

    // Construct the file path
    const file_path = try allocator.alloc(u8, "./html".len + uri.len);
    defer allocator.free(file_path);

    std.mem.copyForwards(u8, file_path[0.."./html".len], "./html");
    std.mem.copyForwards(u8, file_path["./html".len..], uri);

    // Open the file
    var file = try fs.cwd().openFile(file_path, .{ .mode = .read_only });
    defer file.close();

    // Read the file contents
    const file_contents = try file.readToEndAlloc(allocator, 1024);
    defer allocator.free(file_contents);

    // Construct the HTTP response header
    const content_length_str = try std.fmt.allocPrint(allocator, "{d}", .{file_contents.len});
    defer allocator.free(content_length_str);
    const content_type = get_content_type(uri);
    const header = try std.fmt.allocPrint(allocator, "HTTP/1.1 200 OK\r\nContent-Length: {d}\r\nContent-Type: {s}\r\nConnection: Closed\r\n\r\n", .{ file_contents.len, content_type });
    defer allocator.free(header);

    const response = try allocator.alloc(u8, header.len + file_contents.len);
    defer allocator.free(response);

    std.mem.copyForwards(u8, response[0..header.len], header);
    std.mem.copyForwards(u8, response[header.len..], file_contents);

    // Send the response
    try conn.stream.writeAll(response);
}

pub fn send_404(conn: Connection) !void {
    const message = ("HTTP/1.1 404 Not Found\nContent-Length: 50" ++ "\nContent-Type: text/html\n" ++ "Connection: Closed\n\n<html><body>" ++ "<h1>File not found!</h1></body></html>");

    _ = try conn.stream.write(message);
}

const mime_types = Map([]const u8).initComptime(.{
    .{ ".css", "text/css" },
    .{ ".js", "application/javascript" },
    .{ ".png", "image/png" },
    .{ ".jpg", "image/jpeg" },
    .{ ".html", "text/html" },
});

fn get_content_type(uri: []const u8) []const u8 {
    const ext = std.fs.path.extension(uri);
    const mime_type = mime_types.get(ext);
    return mime_type orelse "application/octet-stream";
}
