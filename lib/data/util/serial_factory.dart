import 'package:falcon_gcs/data/util/serial_android.dart';
import 'serial_interface.dart'
    if (dart.library.io) 'serial_android.dart'
    if (dart.library.html) 'serial_web.dart';

SerialInterface createSerialPort([dynamic port]) {
  // The correct class will be used based on the platform.
  return SerialPlatformImpl(port);
}
