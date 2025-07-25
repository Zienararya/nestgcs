class MavlinkMessage {
  final String type;
  final Map<String, dynamic> data;

  MavlinkMessage({required this.type, required this.data});

  factory MavlinkMessage.fromJson(Map<String, dynamic> json) {
    // print('DEBUG: ENTERING MavlinkMessage.fromJson');
    // print('DEBUG: MavlinkMessage.fromJson input = ${json}');
    // Print stack trace to ensure this code is executed
    final type = json['type'] ?? 'Unknown';
    final rawData = json['data'];
    Map<String, dynamic> dataMap;
    if (rawData is Map<String, dynamic>) {
      dataMap = rawData;
    } else if (rawData is Map) {
      dataMap = Map<String, dynamic>.from(rawData);
    } else {
      dataMap = {};
    }
    // print('DEBUG: MavlinkMessage.fromJson output type = $type, data = $dataMap');
    return MavlinkMessage(
      type: type,
      data: dataMap,
    );
  }
}
