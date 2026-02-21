import 'dart:convert';
import 'dart:math' as math;

import '../core/constants/positions.dart';
import '../core/models/app_state.dart';
import '../core/models/formation.dart';
import '../core/models/lineup_assignment.dart';
import '../core/models/movement_path.dart';
import '../core/models/player.dart';
import 'local_storage.dart';

class AppRepository {
  AppRepository(this._storage);

  final LocalStorage _storage;

  Future<AppState> loadState() async {
    final raw = await _storage.readState();
    if (raw == null) {
      return AppState.initial();
    }
    return AppState.fromJson(raw);
  }

  Future<void> saveState(AppState state) async {
    await _storage.writeState(state.toJson());
  }

  AppState setActivePhase(AppState state, String phase) {
    final nextPhase = phase == TacticalPhase.defense
        ? TacticalPhase.defense
        : TacticalPhase.attack;
    if (nextPhase == state.activePhase) {
      return state;
    }
    final fromFormationId = state.activePhase == TacticalPhase.attack
        ? state.attackFormationId
        : state.defenseFormationId;
    final toFormationId = nextPhase == TacticalPhase.attack
        ? state.attackFormationId
        : state.defenseFormationId;
    var mapping = getTransitionMapping(
      state,
      fromFormationId: fromFormationId,
      toFormationId: toFormationId,
    );
    if (mapping.isEmpty) {
      final reverse = getTransitionMapping(
        state,
        fromFormationId: toFormationId,
        toFormationId: fromFormationId,
      );
      if (reverse.isNotEmpty) {
        final inverted = <String, String>{};
        for (final entry in reverse.entries) {
          inverted[entry.value] = entry.key;
        }
        mapping = inverted;
      }
    }
    if (mapping.isEmpty) {
      return state.copyWith(activePhase: nextPhase);
    }
    final remapped = _remapAssignmentsForPhaseTransition(
      state,
      fromPhase: state.activePhase,
      toPhase: nextPhase,
      mapping: mapping,
      fromFormationId: fromFormationId,
      toFormationId: toFormationId,
    );
    return remapped.copyWith(activePhase: nextPhase);
  }

  AppState addPlayer(
    AppState state, {
    required String name,
    required int number,
    required String preferredPosition,
  }) {
    final player = Player(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      number: number,
      preferredPosition: preferredPosition.trim(),
    );
    return state.copyWith(players: [...state.players, player]);
  }

  AppState loadSamplePlayers(AppState state) {
    const samplePlayers = [
      Player(
        id: 'sample-gk-1',
        name: '김지훈',
        number: 1,
        preferredPosition: 'GK',
      ),
      Player(
        id: 'sample-cb-1',
        name: '박민수',
        number: 4,
        preferredPosition: 'CB',
      ),
      Player(
        id: 'sample-cb-2',
        name: '이도현',
        number: 5,
        preferredPosition: 'CB',
      ),
      Player(
        id: 'sample-lb-1',
        name: '최우진',
        number: 3,
        preferredPosition: 'LB',
      ),
      Player(
        id: 'sample-rb-1',
        name: '정현우',
        number: 2,
        preferredPosition: 'RB',
      ),
      Player(
        id: 'sample-dm-1',
        name: '강서준',
        number: 6,
        preferredPosition: 'DM',
      ),
      Player(
        id: 'sample-cm-1',
        name: '오지호',
        number: 8,
        preferredPosition: 'CM',
      ),
      Player(
        id: 'sample-cm-2',
        name: '조태양',
        number: 14,
        preferredPosition: 'CM',
      ),
      Player(
        id: 'sample-lm-1',
        name: '윤도윤',
        number: 11,
        preferredPosition: 'LM',
      ),
      Player(
        id: 'sample-rm-1',
        name: '서지후',
        number: 7,
        preferredPosition: 'RM',
      ),
      Player(
        id: 'sample-lw-1',
        name: '한시온',
        number: 17,
        preferredPosition: 'LW',
      ),
      Player(
        id: 'sample-rw-1',
        name: '임유찬',
        number: 18,
        preferredPosition: 'RW',
      ),
      Player(
        id: 'sample-st-1',
        name: '문하준',
        number: 9,
        preferredPosition: 'ST',
      ),
      Player(
        id: 'sample-st-2',
        name: '신준호',
        number: 10,
        preferredPosition: 'ST',
      ),
    ];

    final clearedAttack = state.attackAssignments
        .map((assignment) => assignment.copyWith(clearPlayer: true))
        .toList();
    final clearedDefense = state.defenseAssignments
        .map((assignment) => assignment.copyWith(clearPlayer: true))
        .toList();

    return state.copyWith(
      players: samplePlayers,
      attackAssignments: clearedAttack,
      defenseAssignments: clearedDefense,
    );
  }

  AppState updatePlayer(
    AppState state, {
    required String playerId,
    required String name,
    required int number,
    required String preferredPosition,
  }) {
    final updated = state.players
        .map(
          (player) => player.id == playerId
              ? player.copyWith(
                  name: name.trim(),
                  number: number,
                  preferredPosition: preferredPosition.trim(),
                )
              : player,
        )
        .toList();
    return state.copyWith(players: updated);
  }

  AppState removePlayer(AppState state, String playerId) {
    final players = state.players
        .where((player) => player.id != playerId)
        .toList();
    final attackAssignments = state.attackAssignments
        .map(
          (assignment) => assignment.playerId == playerId
              ? assignment.copyWith(clearPlayer: true)
              : assignment,
        )
        .toList();
    final defenseAssignments = state.defenseAssignments
        .map(
          (assignment) => assignment.playerId == playerId
              ? assignment.copyWith(clearPlayer: true)
              : assignment,
        )
        .toList();
    return state.copyWith(
      players: players,
      attackAssignments: attackAssignments,
      defenseAssignments: defenseAssignments,
    );
  }

  AppState selectFormation(AppState state, String formationId) {
    if (state.selectedFormationId == formationId) {
      return state;
    }

    final previousFormation = state.selectedFormation;
    final previousAssignments = state.assignments;
    final formation = FormationTemplate.findById(formationId);
    final previousSlotById = {
      for (final slot in previousFormation.slots) slot.id: slot,
    };
    final assignedPlayers = <_AssignedPlayer>[];

    for (final assignment in previousAssignments) {
      final playerId = assignment.playerId;
      if (playerId == null) {
        continue;
      }
      Player? player;
      for (final item in state.players) {
        if (item.id == playerId) {
          player = item;
          break;
        }
      }
      if (player == null) {
        continue;
      }
      assignedPlayers.add(
        _AssignedPlayer(
          player: player,
          x: assignment.x,
          y: assignment.y,
          previousSlotLabel: previousSlotById[assignment.slotId]?.label ?? '',
          previousSlotId: assignment.slotId,
        ),
      );
    }

    final availableSlots = <_TargetSlot>[
      for (final slot in formation.slots)
        _TargetSlot(id: slot.id, label: slot.label, x: slot.x, y: slot.y),
    ];
    final nextAssignments = <LineupAssignment>[];

    for (final assigned in assignedPlayers) {
      final matched = _takeBestMatchedTargetSlot(availableSlots, assigned);
      if (matched != null) {
        nextAssignments.add(
          LineupAssignment(
            slotId: matched.id,
            playerId: assigned.player.id,
            x: matched.x,
            y: matched.y,
          ),
        );
      }
    }

    for (final assigned in assignedPlayers) {
      final alreadyPlaced = nextAssignments.any(
        (assignment) => assignment.playerId == assigned.player.id,
      );
      if (alreadyPlaced || availableSlots.isEmpty) {
        continue;
      }
      final nearest = _takeNearestTargetSlot(
        availableSlots,
        assigned.x,
        assigned.y,
      );
      nextAssignments.add(
        LineupAssignment(
          slotId: nearest.id,
          playerId: assigned.player.id,
          x: nearest.x,
          y: nearest.y,
        ),
      );
    }

    for (final slot in availableSlots) {
      nextAssignments.add(
        LineupAssignment(slotId: slot.id, x: slot.x, y: slot.y),
      );
    }

    return _copyWithActivePhase(
      state,
      formationId: formation.id,
      assignments: nextAssignments,
    );
  }

  AppState assignPlayerToSlot(
    AppState state, {
    required String slotId,
    required String? playerId,
  }) {
    final assignments = state.assignments.map((assignment) {
      if (assignment.slotId == slotId) {
        if (playerId == null) {
          return assignment.copyWith(clearPlayer: true);
        }
        return assignment.copyWith(playerId: playerId);
      }
      if (playerId != null && assignment.playerId == playerId) {
        return assignment.copyWith(clearPlayer: true);
      }
      return assignment;
    }).toList();
    return _copyWithActivePhase(state, assignments: assignments);
  }

  AppState moveSlot(
    AppState state, {
    required String slotId,
    required double x,
    required double y,
  }) {
    final assignments = state.assignments
        .map(
          (assignment) => assignment.slotId == slotId
              ? assignment.copyWith(
                  x: x.clamp(0.06, 0.94),
                  y: y.clamp(0.08, 0.94),
                )
              : assignment,
        )
        .toList();
    return _copyWithActivePhase(state, assignments: assignments);
  }

  AppState setCoachNote(AppState state, String coachNote) {
    return state.copyWith(coachNote: coachNote.trim());
  }

  AppState setMovementPath(
    AppState state, {
    required String slotId,
    required List<PathPoint> points,
  }) {
    final next = <String, List<PathPoint>>{
      ...state.movementPaths,
      slotId: points,
    };
    return _copyWithActivePhase(state, movementPaths: next);
  }

  AppState clearMovementPath(AppState state, String slotId) {
    final next = <String, List<PathPoint>>{...state.movementPaths};
    next.remove(slotId);
    return _copyWithActivePhase(state, movementPaths: next);
  }

  AppState clearCurrentFormationPaths(AppState state) {
    final prefix = '${state.selectedFormationId}-';
    final next = <String, List<PathPoint>>{};
    for (final entry in state.movementPaths.entries) {
      if (!entry.key.startsWith(prefix)) {
        next[entry.key] = entry.value;
      }
    }
    return _copyWithActivePhase(state, movementPaths: next);
  }

  AppState replaceTransitionMapping(
    AppState state, {
    required String fromFormationId,
    required String toFormationId,
    required Map<String, String> mapping,
  }) {
    final key = _mappingKey(fromFormationId, toFormationId);
    final nextMappings = <String, Map<String, String>>{
      ...state.transitionMappings,
    };
    final cleaned = <String, String>{};
    final toUsed = <String>{};
    for (final entry in mapping.entries) {
      if (entry.key.isEmpty || entry.value.isEmpty) {
        continue;
      }
      if (toUsed.contains(entry.value)) {
        continue;
      }
      toUsed.add(entry.value);
      cleaned[entry.key] = entry.value;
    }
    if (cleaned.isEmpty) {
      nextMappings.remove(key);
    } else {
      nextMappings[key] = cleaned;
    }
    return state.copyWith(transitionMappings: nextMappings);
  }

  Map<String, String> getTransitionMapping(
    AppState state, {
    required String fromFormationId,
    required String toFormationId,
  }) {
    final key = _mappingKey(fromFormationId, toFormationId);
    final existing = state.transitionMappings[key];
    if (existing == null) {
      return const {};
    }
    return Map<String, String>.from(existing);
  }

  String buildShareUrl(AppState state, Uri currentUri) {
    final payload = base64UrlEncode(utf8.encode(jsonEncode(state.toJson())));
    final base = currentUri.replace(queryParameters: const {}, fragment: '');
    return base.replace(queryParameters: {'payload': payload}).toString();
  }

  AppState importFromShareText(AppState fallback, String raw) {
    try {
      var payload = raw.trim();
      final uri = Uri.tryParse(payload);
      if (uri != null && uri.queryParameters['payload'] != null) {
        payload = uri.queryParameters['payload']!;
      }

      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(payload)),
      );
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return AppState.fromJson(json);
    } catch (_) {
      return fallback;
    }
  }

  AppState _copyWithActivePhase(
    AppState state, {
    String? formationId,
    List<LineupAssignment>? assignments,
    Map<String, List<PathPoint>>? movementPaths,
  }) {
    if (state.isAttackPhase) {
      return state.copyWith(
        attackFormationId: formationId,
        attackAssignments: assignments,
        attackMovementPaths: movementPaths,
      );
    }
    return state.copyWith(
      defenseFormationId: formationId,
      defenseAssignments: assignments,
      defenseMovementPaths: movementPaths,
    );
  }

  AppState _remapAssignmentsForPhaseTransition(
    AppState state, {
    required String fromPhase,
    required String toPhase,
    required Map<String, String> mapping,
    required String fromFormationId,
    required String toFormationId,
  }) {
    final fromAssignments = fromPhase == TacticalPhase.attack
        ? state.attackAssignments
        : state.defenseAssignments;
    final baseTargetAssignments = toPhase == TacticalPhase.attack
        ? state.attackAssignments
        : state.defenseAssignments;
    final sourcePlayerBySlot = <String, String>{};
    for (final assignment in fromAssignments) {
      final playerId = assignment.playerId;
      if (playerId != null) {
        sourcePlayerBySlot[assignment.slotId] = playerId;
      }
    }

    final nextAssignments = <LineupAssignment>[
      for (final assignment in baseTargetAssignments)
        LineupAssignment(
          slotId: assignment.slotId,
          playerId: assignment.playerId,
          x: assignment.x,
          y: assignment.y,
        ),
    ];
    final fromFormation = FormationTemplate.findById(fromFormationId);
    final fromSlotLabelById = {
      for (final slot in fromFormation.slots)
        slot.id: normalizePosition(slot.label),
    };
    final toFormation = FormationTemplate.findById(toFormationId);
    final toSlotIdByLabel = <String, String>{};
    for (final slot in toFormation.slots) {
      toSlotIdByLabel.putIfAbsent(normalizePosition(slot.label), () => slot.id);
    }
    void clearPlayer(String playerId) {
      for (var i = 0; i < nextAssignments.length; i++) {
        if (nextAssignments[i].playerId == playerId) {
          nextAssignments[i] = nextAssignments[i].copyWith(clearPlayer: true);
        }
      }
    }

    for (final entry in mapping.entries) {
      final fromSlotId = entry.key;
      final mappedTarget = entry.value;
      final targetSlotId =
          nextAssignments.any((it) => it.slotId == mappedTarget)
          ? mappedTarget
          : toSlotIdByLabel[normalizePosition(_slotLabelFromId(mappedTarget))];

      var playerId = sourcePlayerBySlot[fromSlotId];
      if (playerId == null) {
        final slotLabel = fromSlotLabelById[fromSlotId];
        if (slotLabel != null) {
          playerId = _findStrictFallbackPlayer(
            state: state,
            fromAssignments: fromAssignments,
            slotLabel: slotLabel,
          );
        }
      }
      if (playerId == null) {
        continue;
      }
      if (targetSlotId == null) {
        continue;
      }

      clearPlayer(playerId);
      for (var i = 0; i < nextAssignments.length; i++) {
        if (nextAssignments[i].slotId == targetSlotId) {
          nextAssignments[i] = nextAssignments[i].copyWith(playerId: playerId);
          break;
        }
      }
    }

    if (toPhase == TacticalPhase.attack) {
      return state.copyWith(attackAssignments: nextAssignments);
    }
    return state.copyWith(defenseAssignments: nextAssignments);
  }

  String _slotLabelFromId(String slotId) {
    final index = slotId.lastIndexOf('-');
    if (index < 0 || index + 1 >= slotId.length) {
      return slotId;
    }
    return slotId.substring(index + 1);
  }

  String? _findStrictFallbackPlayer({
    required AppState state,
    required List<LineupAssignment> fromAssignments,
    required String slotLabel,
  }) {
    for (final assignment in fromAssignments) {
      final playerId = assignment.playerId;
      if (playerId == null) {
        continue;
      }
      Player? player;
      for (final item in state.players) {
        if (item.id == playerId) {
          player = item;
          break;
        }
      }
      if (player == null) {
        continue;
      }
      if (normalizePosition(player.preferredPosition) == slotLabel) {
        return playerId;
      }
    }
    return null;
  }

  _TargetSlot? _takeBestMatchedTargetSlot(
    List<_TargetSlot> availableSlots,
    _AssignedPlayer assigned,
  ) {
    final preferredMatches = availableSlots
        .where(
          (slot) => matchesPreferredForSlot(
            assigned.player.preferredPosition,
            slot.label,
          ),
        )
        .toList();
    if (preferredMatches.isNotEmpty) {
      return _takeNearestTargetSlot(
        preferredMatches,
        assigned.x,
        assigned.y,
        source: availableSlots,
      );
    }

    final previousLabelMatches = availableSlots
        .where(
          (slot) =>
              normalizePosition(slot.label) ==
              normalizePosition(assigned.previousSlotLabel),
        )
        .toList();
    if (previousLabelMatches.isNotEmpty) {
      return _takeNearestTargetSlot(
        previousLabelMatches,
        assigned.x,
        assigned.y,
        source: availableSlots,
      );
    }
    return null;
  }

  _TargetSlot _takeNearestTargetSlot(
    List<_TargetSlot> candidates,
    double x,
    double y, {
    List<_TargetSlot>? source,
  }) {
    _TargetSlot best = candidates.first;
    var bestDistance = _distance(best.x, best.y, x, y);
    for (final slot in candidates.skip(1)) {
      final distance = _distance(slot.x, slot.y, x, y);
      if (distance < bestDistance) {
        best = slot;
        bestDistance = distance;
      }
    }
    (source ?? candidates).removeWhere((slot) => slot.id == best.id);
    return best;
  }

  double _distance(double ax, double ay, double bx, double by) {
    final dx = ax - bx;
    final dy = ay - by;
    return math.sqrt(dx * dx + dy * dy);
  }

  String _mappingKey(String fromFormationId, String toFormationId) {
    return '$fromFormationId->$toFormationId';
  }
}

class _AssignedPlayer {
  _AssignedPlayer({
    required this.player,
    required this.x,
    required this.y,
    required this.previousSlotLabel,
    required this.previousSlotId,
  });

  final Player player;
  final double x;
  final double y;
  final String previousSlotLabel;
  final String previousSlotId;
}

class _TargetSlot {
  _TargetSlot({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
  });

  final String id;
  final String label;
  final double x;
  final double y;
}
