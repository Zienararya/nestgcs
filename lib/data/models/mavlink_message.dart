class MavlinkMessage {
  final String type;
  final Map<String, dynamic> data;

  MavlinkMessage({required this.type, required this.data});

  factory MavlinkMessage.fromJson(Map<String, dynamic> json) {
    return MavlinkMessage(
      type: json['type'] ?? 'Unknown',
      data: Map<String, dynamic>.from(json['data']),
    );
  }
}
