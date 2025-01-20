const std = @import("std");
const net = @import("std").net;

pub const Socket = struct {
    _address: net.Address,
    _stream: std.net.Stream,

    pub fn init(host: [4]u8, port: u16) !Socket {
        const addr = net.Address.initIp4(host, port);
        const socket = try std.posix.socket(addr.any.family, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);
        const stream = net.Stream{ .handle = socket };
        return Socket{ ._address = addr, ._stream = stream };
    }
};
