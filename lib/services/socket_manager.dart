import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketManager {
  SocketManager(this.url);

  final String url;

  io.Socket connectToSocket() {
    io.Socket socket = io.io(url, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.on('connect', (_) => print('Connected'));
    socket.on('disconnect', (_) => print('Disconnected'));

    // Error handling
    socket.on('connect_error', (error) {
      print('Connection error: $error');
    });

    // Connect to the server
    socket.connect();

    return socket;
  }
}
