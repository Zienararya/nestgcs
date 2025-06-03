import 'dart:typed_data';

abstract class SerialInterface {
  Future<List<String>> getAvailablePorts(); // Tambahkan ini
  Future<void> open();
  Future<void> write(Uint8List data);
  Future<List<int>> read();
  Future<void> close();
}
