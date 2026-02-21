class PathPoint {
  const PathPoint({required this.x, required this.y});

  final double x;
  final double y;

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }

  factory PathPoint.fromJson(Map<String, dynamic> json) {
    return PathPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}
