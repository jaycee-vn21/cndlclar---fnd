import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:cndlclar/utils/config.dart';

class SocketManager {
  SocketManager(this.url);

  final String url;

  io.Socket connectToSocket() {
    io.Socket socket = io.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'auth': {'deviceToken': AppConfig.deviceToken},
      'extraHeaders': {'x-device-token': AppConfig.deviceToken},
    });

    socket.on('connect', (_) => debugPrint('Connected'));
    socket.on('disconnect', (_) => debugPrint('Disconnected'));

    // Error handling
    socket.on('connect_error', (error) {
      debugPrint('Connection error: $error');
    });

    // Connect to the server
    socket.connect();

    return socket;
  }
}
