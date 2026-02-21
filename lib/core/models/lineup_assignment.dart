class LineupAssignment {
  const LineupAssignment({
    required this.slotId,
    required this.x,
    required this.y,
    this.playerId,
  });

  final String slotId;
  final String? playerId;
  final double x;
  final double y;

  LineupAssignment copyWith({
    String? slotId,
    String? playerId,
    bool clearPlayer = false,
    double? x,
    double? y,
  }) {
    return LineupAssignment(
      slotId: slotId ?? this.slotId,
      playerId: clearPlayer ? null : (playerId ?? this.playerId),
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  Map<String, dynamic> toJson() {
    return {'slotId': slotId, 'playerId': playerId, 'x': x, 'y': y};
  }

  factory LineupAssignment.fromJson(Map<String, dynamic> json) {
    return LineupAssignment(
      slotId: json['slotId'] as String,
      playerId: json['playerId'] as String?,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}
