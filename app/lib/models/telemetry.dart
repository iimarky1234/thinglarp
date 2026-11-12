class TelemetryPoint {
  final DateTime time;
  final double value;
  final double? min;
  final double? max;

  TelemetryPoint({
    required this.time,
    required this.value,
    this.min,
    this.max,
  });

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) {
    return TelemetryPoint(
      time: DateTime.parse(json['time'] as String),
      value: (json['value'] as num).toDouble(),
      min: json['min'] != null ? (json['min'] as num).toDouble() : null,
      max: json['max'] != null ? (json['max'] as num).toDouble() : null,
    );
  }
}

class ChannelDataResponse {
  final int channelId;
  final String resolution;
  final Map<String, List<TelemetryPoint>> fields;

  ChannelDataResponse({
    required this.channelId,
    required this.resolution,
    required this.fields,
  });

  factory ChannelDataResponse.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'] as Map<String, dynamic>? ?? {};
    final parsedFields = <String, List<TelemetryPoint>>{};

    rawFields.forEach((key, listVal) {
      if (listVal is List) {
        parsedFields[key] = listVal
            .map((item) => TelemetryPoint.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    });

    return ChannelDataResponse(
      channelId: json['channel_id'] as int,
      resolution: json['resolution'] as String? ?? 'raw',
      fields: parsedFields,
    );
  }
}
