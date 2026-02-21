class Player {
  const Player({
    required this.id,
    required this.name,
    required this.number,
    required this.preferredPosition,
  });

  final String id;
  final String name;
  final int number;
  final String preferredPosition;

  Player copyWith({
    String? id,
    String? name,
    int? number,
    String? preferredPosition,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      preferredPosition: preferredPosition ?? this.preferredPosition,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'number': number,
      'preferredPosition': preferredPosition,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      name: json['name'] as String,
      number: json['number'] as int,
      preferredPosition: json['preferredPosition'] as String,
    );
  }
}
