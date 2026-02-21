import 'formation.dart';
import 'lineup_assignment.dart';
import 'movement_path.dart';
import 'player.dart';

class TacticalPhase {
  static const attack = 'attack';
  static const defense = 'defense';
}

class AppState {
  const AppState({
    required this.players,
    required this.activePhase,
    required this.attackFormationId,
    required this.defenseFormationId,
    required this.attackAssignments,
    required this.defenseAssignments,
    required this.attackMovementPaths,
    required this.defenseMovementPaths,
    required this.transitionMappings,
    required this.coachNote,
  });

  final List<Player> players;
  final String activePhase;
  final String attackFormationId;
  final String defenseFormationId;
  final List<LineupAssignment> attackAssignments;
  final List<LineupAssignment> defenseAssignments;
  final Map<String, List<PathPoint>> attackMovementPaths;
  final Map<String, List<PathPoint>> defenseMovementPaths;
  final Map<String, Map<String, String>> transitionMappings;
  final String coachNote;

  bool get isAttackPhase => activePhase == TacticalPhase.attack;
  String get selectedFormationId =>
      isAttackPhase ? attackFormationId : defenseFormationId;
  List<LineupAssignment> get assignments =>
      isAttackPhase ? attackAssignments : defenseAssignments;
  Map<String, List<PathPoint>> get movementPaths =>
      isAttackPhase ? attackMovementPaths : defenseMovementPaths;
  FormationTemplate get selectedFormation =>
      FormationTemplate.findById(selectedFormationId);

  AppState copyWith({
    List<Player>? players,
    String? activePhase,
    String? attackFormationId,
    String? defenseFormationId,
    List<LineupAssignment>? attackAssignments,
    List<LineupAssignment>? defenseAssignments,
    Map<String, List<PathPoint>>? attackMovementPaths,
    Map<String, List<PathPoint>>? defenseMovementPaths,
    Map<String, Map<String, String>>? transitionMappings,
    String? coachNote,
  }) {
    return AppState(
      players: players ?? this.players,
      activePhase: activePhase ?? this.activePhase,
      attackFormationId: attackFormationId ?? this.attackFormationId,
      defenseFormationId: defenseFormationId ?? this.defenseFormationId,
      attackAssignments: attackAssignments ?? this.attackAssignments,
      defenseAssignments: defenseAssignments ?? this.defenseAssignments,
      attackMovementPaths: attackMovementPaths ?? this.attackMovementPaths,
      defenseMovementPaths: defenseMovementPaths ?? this.defenseMovementPaths,
      transitionMappings: transitionMappings ?? this.transitionMappings,
      coachNote: coachNote ?? this.coachNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'players': players.map((player) => player.toJson()).toList(),
      'activePhase': activePhase,
      'attackFormationId': attackFormationId,
      'defenseFormationId': defenseFormationId,
      'attackAssignments': attackAssignments
          .map((assignment) => assignment.toJson())
          .toList(),
      'defenseAssignments': defenseAssignments
          .map((assignment) => assignment.toJson())
          .toList(),
      'attackMovementPaths': attackMovementPaths.map(
        (slotId, points) =>
            MapEntry(slotId, points.map((point) => point.toJson()).toList()),
      ),
      'defenseMovementPaths': defenseMovementPaths.map(
        (slotId, points) =>
            MapEntry(slotId, points.map((point) => point.toJson()).toList()),
      ),
      'transitionMappings': transitionMappings.map(
        (pairKey, slotMap) => MapEntry(pairKey, slotMap),
      ),
      'coachNote': coachNote,
    };
  }

  factory AppState.fromJson(Map<String, dynamic> json) {
    final formations = FormationTemplate.defaults.map((it) => it.id).toSet();

    // Backward compatibility for old single-formation schema.
    final legacyFormationId = json['selectedFormationId'] as String?;
    final legacyAttackFormation =
        legacyFormationId != null && formations.contains(legacyFormationId)
        ? legacyFormationId
        : FormationTemplate.defaults.first.id;
    final legacyAttackAssignments = _buildAssignments(
      json['assignments'] as List<dynamic>?,
      FormationTemplate.findById(legacyAttackFormation),
    );
    final legacyAttackPaths = _parseMovementPaths(
      json['movementPaths'] as Map<String, dynamic>?,
    );

    final activePhaseRaw = json['activePhase'] as String?;
    final activePhase = activePhaseRaw == TacticalPhase.defense
        ? TacticalPhase.defense
        : TacticalPhase.attack;

    final attackFormationIdRaw = json['attackFormationId'] as String?;
    final attackFormationId =
        attackFormationIdRaw != null &&
            formations.contains(attackFormationIdRaw)
        ? attackFormationIdRaw
        : legacyAttackFormation;

    final defenseFormationIdRaw = json['defenseFormationId'] as String?;
    final defenseFormationId =
        defenseFormationIdRaw != null &&
            formations.contains(defenseFormationIdRaw)
        ? defenseFormationIdRaw
        : legacyAttackFormation;

    final attackAssignments = _buildAssignments(
      json['attackAssignments'] as List<dynamic>?,
      FormationTemplate.findById(attackFormationId),
      fallback: legacyAttackAssignments,
    );
    final defenseAssignments = _buildAssignments(
      json['defenseAssignments'] as List<dynamic>?,
      FormationTemplate.findById(defenseFormationId),
      fallback: legacyAttackAssignments,
    );
    final attackMovementPaths = _parseMovementPaths(
      json['attackMovementPaths'] as Map<String, dynamic>?,
      fallback: legacyAttackPaths,
    );
    final defenseMovementPaths = _parseMovementPaths(
      json['defenseMovementPaths'] as Map<String, dynamic>?,
      fallback: legacyAttackPaths,
    );
    final transitionMappings = _parseTransitionMappings(
      json['transitionMappings'] as Map<String, dynamic>?,
    );

    final players = (json['players'] as List<dynamic>? ?? [])
        .map((item) => Player.fromJson(item as Map<String, dynamic>))
        .toList();

    return AppState(
      players: players,
      activePhase: activePhase,
      attackFormationId: attackFormationId,
      defenseFormationId: defenseFormationId,
      attackAssignments: attackAssignments,
      defenseAssignments: defenseAssignments,
      attackMovementPaths: attackMovementPaths,
      defenseMovementPaths: defenseMovementPaths,
      transitionMappings: transitionMappings,
      coachNote: json['coachNote'] as String? ?? '',
    );
  }

  factory AppState.initial() {
    final attackFormation = FormationTemplate.defaults.first;
    final defenseFormation = FormationTemplate.findById('442');

    return AppState(
      players: const [],
      activePhase: TacticalPhase.attack,
      attackFormationId: attackFormation.id,
      defenseFormationId: defenseFormation.id,
      attackAssignments: attackFormation.slots
          .map(
            (slot) => LineupAssignment(slotId: slot.id, x: slot.x, y: slot.y),
          )
          .toList(),
      defenseAssignments: defenseFormation.slots
          .map(
            (slot) => LineupAssignment(slotId: slot.id, x: slot.x, y: slot.y),
          )
          .toList(),
      attackMovementPaths: const {},
      defenseMovementPaths: const {},
      transitionMappings: const {},
      coachNote: '',
    );
  }

  static List<LineupAssignment> _buildAssignments(
    List<dynamic>? rawAssignments,
    FormationTemplate formation, {
    List<LineupAssignment>? fallback,
  }) {
    final assignmentMap = <String, LineupAssignment>{};
    for (final raw in rawAssignments ?? <dynamic>[]) {
      final assignment = LineupAssignment.fromJson(raw as Map<String, dynamic>);
      assignmentMap[assignment.slotId] = assignment;
    }

    if (assignmentMap.isEmpty && fallback != null && fallback.isNotEmpty) {
      for (final item in fallback) {
        assignmentMap[item.slotId] = item;
      }
    }

    return formation.slots.map((slot) {
      final existing = assignmentMap[slot.id];
      if (existing != null) {
        return existing;
      }
      return LineupAssignment(slotId: slot.id, x: slot.x, y: slot.y);
    }).toList();
  }

  static Map<String, List<PathPoint>> _parseMovementPaths(
    Map<String, dynamic>? rawMovementPaths, {
    Map<String, List<PathPoint>>? fallback,
  }) {
    final movementPaths = <String, List<PathPoint>>{};
    if (rawMovementPaths != null) {
      for (final entry in rawMovementPaths.entries) {
        final points = <PathPoint>[];
        for (final rawPoint in (entry.value as List<dynamic>? ?? [])) {
          if (rawPoint is Map) {
            points.add(
              PathPoint.fromJson(
                rawPoint.map((key, value) => MapEntry(key.toString(), value)),
              ),
            );
          }
        }
        if (points.isNotEmpty) {
          movementPaths[entry.key] = points;
        }
      }
    }

    if (movementPaths.isEmpty && fallback != null && fallback.isNotEmpty) {
      return fallback.map((key, value) => MapEntry(key, [...value]));
    }
    return movementPaths;
  }

  static Map<String, Map<String, String>> _parseTransitionMappings(
    Map<String, dynamic>? raw,
  ) {
    final mappings = <String, Map<String, String>>{};
    if (raw == null) {
      return mappings;
    }
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final slotMap = <String, String>{};
      for (final slotEntry in value.entries) {
        final fromSlot = slotEntry.key.toString();
        final toSlotValue = slotEntry.value;
        if (toSlotValue is String && toSlotValue.isNotEmpty) {
          slotMap[fromSlot] = toSlotValue;
        }
      }
      if (slotMap.isNotEmpty) {
        mappings[entry.key] = slotMap;
      }
    }
    return mappings;
  }
}
