import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/positions.dart';
import '../../core/models/app_state.dart';
import '../../core/models/formation.dart';
import '../../core/models/lineup_assignment.dart';
import '../../core/models/movement_path.dart';
import '../../core/models/player.dart';
import '../state/app_controller.dart';

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _playbackController;
  late final AnimationController _phaseSwitchController;
  String? _selectedSlotId;
  bool _pathEditMode = false;
  Map<String, Offset> _phaseFromPlayerPositions = const {};
  Map<String, Offset> _phaseFromSlotPositions = const {};

  @override
  void initState() {
    super.initState();
    _playbackController =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..addListener(() {
            setState(() {});
          });
    _phaseSwitchController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        )..addListener(() {
          setState(() {});
        });
  }

  @override
  void dispose() {
    _playbackController.dispose();
    _phaseSwitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(appControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('전술 보드'),
        actions: [
          IconButton(
            tooltip: '재생/정지',
            onPressed: _togglePlayback,
            icon: Icon(
              _playbackController.isAnimating ? Icons.pause : Icons.play_arrow,
            ),
          ),
          IconButton(
            tooltip: '코치 노트',
            onPressed: () => _openCoachNoteDialog(context),
            icon: const Icon(Icons.sticky_note_2_outlined),
          ),
          IconButton(
            tooltip: '공유 링크 복사',
            onPressed: () => _copyShareUrl(context),
            icon: const Icon(Icons.link),
          ),
          IconButton(
            tooltip: '공유 링크 불러오기',
            onPressed: () => _importFromShareLink(context),
            icon: const Icon(Icons.download_outlined),
          ),
          IconButton(
            tooltip: '현재 포메이션 경로 초기화',
            onPressed: () => _clearCurrentFormationPaths(context),
            icon: const Icon(Icons.auto_fix_high_outlined),
          ),
          IconButton(
            tooltip: '공격/수비 전환 매핑 편집',
            onPressed: () {
              final current = ref.read(appControllerProvider).value;
              if (current != null) {
                _openTransitionMappingEditor(context, current);
              }
            },
            icon: const Icon(Icons.alt_route),
          ),
        ],
      ),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('오류: $error')),
        data: (state) {
          final formation = state.selectedFormation;
          final media = MediaQuery.sizeOf(context);
          final isTablet = media.shortestSide >= 600;
          return Column(
            children: [
              _buildInfoHeader(state, formation),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxBoardWidth = isTablet
                          ? math.min(constraints.maxWidth, 820.0)
                          : constraints.maxWidth;
                      const pitchAspectRatio = 0.62;
                      final pitchWidth = math.min(
                        maxBoardWidth,
                        constraints.maxHeight * pitchAspectRatio,
                      );
                      final pitchHeight = pitchWidth / pitchAspectRatio;
                      final markerSize =
                          (pitchWidth * (isTablet ? 0.072 : 0.10)).clamp(
                            42.0,
                            isTablet ? 72.0 : 62.0,
                          );
                      final markerFontSize = (markerSize * 0.26).clamp(
                        11.0,
                        18.0,
                      );

                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: pitchWidth,
                          height: pitchHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F8F47),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Stack(
                              children: [
                                CustomPaint(
                                  size: Size(pitchWidth, pitchHeight),
                                  painter: _PitchPainter(),
                                ),
                                CustomPaint(
                                  size: Size(pitchWidth, pitchHeight),
                                  painter: _PathPainter(
                                    assignments: state.assignments,
                                    movementPaths: state.movementPaths,
                                    selectedSlotId: _selectedSlotId,
                                    progress: _playbackController.value,
                                  ),
                                ),
                                if (_pathEditMode) ...[
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onTapUp: (details) => _addPathPoint(
                                        details.localPosition,
                                        Size(pitchWidth, pitchHeight),
                                        state,
                                      ),
                                      child: Container(
                                        color: Colors.transparent,
                                      ),
                                    ),
                                  ),
                                ],
                                ...formation.slots.map(
                                  (slot) => _buildSlot(
                                    context: context,
                                    state: state,
                                    slot: slot,
                                    assignment: _findAssignment(state, slot.id),
                                    width: pitchWidth,
                                    height: pitchHeight,
                                    markerSize: markerSize,
                                    markerFontSize: markerFontSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_pathEditMode) _buildPathEditBar(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoHeader(AppState state, FormationTemplate formation) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${state.isAttackPhase ? '공격' : '수비'} 포메이션: ${formation.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '선수 ${state.players.length}명',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<String>(
                  value: TacticalPhase.attack,
                  label: Text('공격'),
                ),
                ButtonSegment<String>(
                  value: TacticalPhase.defense,
                  label: Text('수비'),
                ),
              ],
              selected: {state.activePhase},
              onSelectionChanged: (selected) {
                if (selected.isEmpty) {
                  return;
                }
                _switchPhase(selected.first, state);
              },
            ),
          ),
          if (state.coachNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '코치 노트: ${state.coachNote}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1B4332),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPathEditBar(BuildContext context, AppState state) {
    final selectedSlotId = _selectedSlotId;
    final points = selectedSlotId == null
        ? const <PathPoint>[]
        : (state.movementPaths[selectedSlotId] ?? const <PathPoint>[]);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 180,
                child: Text(
                  selectedSlotId == null
                      ? '선수를 먼저 선택하세요'
                      : '경로 편집: ${points.length} 포인트',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: selectedSlotId == null
                    ? null
                    : () {
                        final next = [...points];
                        if (next.isNotEmpty) {
                          next.removeLast();
                        }
                        ref
                            .read(appControllerProvider.notifier)
                            .setMovementPath(
                              slotId: selectedSlotId,
                              points: next,
                            );
                      },
                child: const Text('되돌리기'),
              ),
              TextButton(
                onPressed: selectedSlotId == null
                    ? null
                    : () => ref
                          .read(appControllerProvider.notifier)
                          .clearMovementPath(selectedSlotId),
                child: const Text('초기화'),
              ),
              FilledButton(
                onPressed: () => setState(() => _pathEditMode = false),
                child: const Text('완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlot({
    required BuildContext context,
    required AppState state,
    required FormationSlot slot,
    required LineupAssignment assignment,
    required double width,
    required double height,
    required double markerSize,
    required double markerFontSize,
  }) {
    final player = _findPlayer(state.players, assignment.playerId);
    final animated = _animatedPositionForSlot(state, slot.id, assignment);
    final left = animated.dx * width - markerSize / 2;
    final top = animated.dy * height - markerSize / 2;
    final selected = _selectedSlotId == slot.id;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSlotId = slot.id;
          });
          if (!_pathEditMode) {
            _openAssignSheet(context, state, slot.id);
          }
        },
        onLongPress: () => _openAssignSheet(context, state, slot.id),
        onPanUpdate: _pathEditMode
            ? null
            : (details) {
                final nextX =
                    (left + details.delta.dx + markerSize / 2) / width;
                final nextY =
                    (top + details.delta.dy + markerSize / 2) / height;
                ref
                    .read(appControllerProvider.notifier)
                    .moveSlot(slotId: slot.id, x: nextX, y: nextY);
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: markerSize,
          height: markerSize,
          decoration: BoxDecoration(
            color: player == null
                ? const Color(0xCC546E7A)
                : const Color(0xFF0A3D91),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.amber : Colors.white,
              width: selected ? 3 : 2,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x80FFC107),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: player == null
              ? Text(
                  slot.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: markerFontSize,
                  ),
                  textScaler: TextScaler.noScaling,
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${player.number}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: markerFontSize,
                        ),
                        textScaler: TextScaler.noScaling,
                      ),
                      Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: (markerFontSize * 0.62).clamp(8, 13),
                        ),
                        textScaler: TextScaler.noScaling,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  LineupAssignment _findAssignment(AppState state, String slotId) {
    return state.assignments.firstWhere(
      (assignment) => assignment.slotId == slotId,
    );
  }

  Player? _findPlayer(List<Player> players, String? playerId) {
    if (playerId == null) {
      return null;
    }
    for (final player in players) {
      if (player.id == playerId) {
        return player;
      }
    }
    return null;
  }

  Offset _animatedPositionForSlot(
    AppState state,
    String slotId,
    LineupAssignment assignment,
  ) {
    if (_phaseSwitchController.isAnimating) {
      final playerId = assignment.playerId;
      final from = playerId == null
          ? _phaseFromSlotPositions[slotId]
          : (_phaseFromPlayerPositions[playerId] ??
                _phaseFromSlotPositions[slotId]);
      if (from != null) {
        final t = Curves.easeInOut.transform(_phaseSwitchController.value);
        final x = from.dx + (assignment.x - from.dx) * t;
        final y = from.dy + (assignment.y - from.dy) * t;
        return Offset(x, y);
      }
    }

    if (!_playbackController.isAnimating) {
      return Offset(assignment.x, assignment.y);
    }

    final points = _pathWithStart(assignment, state.movementPaths[slotId]);
    if (points.length < 2) {
      return Offset(assignment.x, assignment.y);
    }

    final segmentCount = points.length - 1;
    final scaled = _playbackController.value * segmentCount;
    final segmentIndex = math.min(segmentCount - 1, scaled.floor());
    final segmentT = scaled - segmentIndex;
    final start = points[segmentIndex];
    final end = points[segmentIndex + 1];
    return Offset(
      start.x + (end.x - start.x) * segmentT,
      start.y + (end.y - start.y) * segmentT,
    );
  }

  void _togglePlayback() {
    if (_playbackController.isAnimating) {
      _playbackController.stop();
      setState(() {});
      return;
    }
    if (_playbackController.value >= 0.999) {
      _playbackController.value = 0;
    }
    _playbackController.repeat();
    setState(() {});
  }

  Future<void> _switchPhase(String phase, AppState currentState) async {
    if (phase == currentState.activePhase) {
      return;
    }

    final fromMap = <String, Offset>{};
    final fromSlotMap = _buildPhaseSwitchSlotMap(currentState, phase);
    for (final assignment in currentState.assignments) {
      final playerId = assignment.playerId;
      if (playerId != null) {
        fromMap[playerId] = Offset(assignment.x, assignment.y);
      }
    }
    setState(() {
      _selectedSlotId = null;
      _phaseFromPlayerPositions = fromMap;
      _phaseFromSlotPositions = fromSlotMap;
    });
    await ref.read(appControllerProvider.notifier).setActivePhase(phase);
    if (!mounted) {
      return;
    }
    _phaseSwitchController.forward(from: 0);
  }

  Map<String, Offset> _buildPhaseSwitchSlotMap(
    AppState state,
    String nextPhase,
  ) {
    final fromFormationId = state.isAttackPhase
        ? state.attackFormationId
        : state.defenseFormationId;
    final toFormationId = nextPhase == TacticalPhase.attack
        ? state.attackFormationId
        : state.defenseFormationId;
    final toFormation = FormationTemplate.findById(toFormationId);
    final toSlotIds = toFormation.slots.map((slot) => slot.id).toSet();
    final toSlotIdByLabel = <String, String>{};
    for (final slot in toFormation.slots) {
      toSlotIdByLabel.putIfAbsent(normalizePosition(slot.label), () => slot.id);
    }

    var mapping = ref
        .read(appControllerProvider.notifier)
        .getTransitionMapping(
          fromFormationId: fromFormationId,
          toFormationId: toFormationId,
        );
    if (mapping.isEmpty) {
      final reverse = ref
          .read(appControllerProvider.notifier)
          .getTransitionMapping(
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

    final fromPosBySlot = <String, Offset>{
      for (final assignment in state.assignments)
        assignment.slotId: Offset(assignment.x, assignment.y),
    };

    final result = <String, Offset>{};
    for (final entry in mapping.entries) {
      final fromPosition = fromPosBySlot[entry.key];
      if (fromPosition == null) {
        continue;
      }
      final mappedTarget = entry.value;
      final targetSlotId = toSlotIds.contains(mappedTarget)
          ? mappedTarget
          : toSlotIdByLabel[normalizePosition(_slotLabelFromId(mappedTarget))];
      if (targetSlotId != null) {
        result[targetSlotId] = fromPosition;
      }
    }

    final sourceByLabel = <String, Offset>{};
    final fromFormation = FormationTemplate.findById(fromFormationId);
    for (final slot in fromFormation.slots) {
      final position = fromPosBySlot[slot.id];
      if (position != null) {
        sourceByLabel.putIfAbsent(
          normalizePosition(slot.label),
          () => position,
        );
      }
    }
    for (final slot in toFormation.slots) {
      if (result.containsKey(slot.id)) {
        continue;
      }
      final fallback = sourceByLabel[normalizePosition(slot.label)];
      if (fallback != null) {
        result[slot.id] = fallback;
      }
    }
    return result;
  }

  String _slotLabelFromId(String slotId) {
    final index = slotId.lastIndexOf('-');
    if (index < 0 || index + 1 >= slotId.length) {
      return slotId;
    }
    return slotId.substring(index + 1);
  }

  Future<void> _clearCurrentFormationPaths(BuildContext context) async {
    await ref.read(appControllerProvider.notifier).clearCurrentFormationPaths();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현재 포메이션 경로를 초기화했습니다.')));
    }
  }

  Future<void> _openTransitionMappingEditor(
    BuildContext context,
    AppState state,
  ) async {
    final fromFormationId = state.isAttackPhase
        ? state.attackFormationId
        : state.defenseFormationId;
    final toFormationId = state.isAttackPhase
        ? state.defenseFormationId
        : state.attackFormationId;
    final fromLabel = state.isAttackPhase ? '공격' : '수비';
    final toLabel = state.isAttackPhase ? '수비' : '공격';

    final fromFormation = FormationTemplate.findById(fromFormationId);
    final toFormation = FormationTemplate.findById(toFormationId);
    final initial = ref
        .read(appControllerProvider.notifier)
        .getTransitionMapping(
          fromFormationId: fromFormationId,
          toFormationId: toFormationId,
        );
    final draft = <String, String>{...initial};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.86,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$fromLabel(${fromFormation.name}) -> $toLabel(${toFormation.name})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(draft.clear);
                            },
                            child: const Text('모두 해제'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: fromFormation.slots.length,
                        itemBuilder: (context, index) {
                          final fromSlot = fromFormation.slots[index];
                          final mappedTo = draft[fromSlot.id];
                          final usedTargets = draft.entries
                              .where((entry) => entry.key != fromSlot.id)
                              .map((entry) => entry.value)
                              .toSet();
                          final candidates = toFormation.slots
                              .where(
                                (slot) =>
                                    !usedTargets.contains(slot.id) ||
                                    slot.id == mappedTo,
                              )
                              .toList();
                          return ListTile(
                            title: Text('${fromSlot.label} (${fromSlot.id})'),
                            subtitle: DropdownButtonFormField<String?>(
                              isExpanded: true,
                              initialValue: mappedTo,
                              decoration: const InputDecoration(
                                labelText: '이동 대상 슬롯',
                              ),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('자동 배치 사용'),
                                ),
                                ...candidates.map(
                                  (slot) => DropdownMenuItem<String?>(
                                    value: slot.id,
                                    child: Text('${slot.label} (${slot.id})'),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == null || value.isEmpty) {
                                    draft.remove(fromSlot.id);
                                  } else {
                                    draft.removeWhere(
                                      (key, target) =>
                                          key != fromSlot.id && target == value,
                                    );
                                    draft[fromSlot.id] = value;
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('취소'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () async {
                                await ref
                                    .read(appControllerProvider.notifier)
                                    .replaceTransitionMapping(
                                      fromFormationId: fromFormationId,
                                      toFormationId: toFormationId,
                                      mapping: draft,
                                    );
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('전환 매핑을 저장했습니다.'),
                                    ),
                                  );
                                }
                              },
                              child: const Text('저장'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCoachNoteDialog(BuildContext context) async {
    final state = ref.read(appControllerProvider).value;
    final controller = TextEditingController(text: state?.coachNote ?? '');
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('코치 노트'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '오늘 전술 지시사항을 입력하세요'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
    if (shouldSave == true) {
      await ref
          .read(appControllerProvider.notifier)
          .setCoachNote(controller.text.trim());
    }
  }

  Future<void> _copyShareUrl(BuildContext context) async {
    final url = ref.read(appControllerProvider.notifier).buildShareUrl();
    if (url == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      final isWebUrl = url.startsWith('http://') || url.startsWith('https://');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isWebUrl
                ? '공유 링크를 클립보드에 복사했습니다.'
                : '링크를 복사했습니다. 웹 URL은 --dart-define=WEB_SHARE_BASE_URL 로 설정하세요.',
          ),
        ),
      );
    }
  }

  Future<void> _importFromShareLink(BuildContext context) async {
    final controller = TextEditingController();
    final shouldLoad = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('공유 링크 불러오기'),
          content: TextField(
            controller: controller,
            maxLines: 2,
            decoration: const InputDecoration(hintText: '공유 URL 또는 payload 입력'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('불러오기'),
            ),
          ],
        );
      },
    );
    if (shouldLoad != true) {
      return;
    }
    final ok = await ref
        .read(appControllerProvider.notifier)
        .importFromShareText(controller.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '공유 전술을 불러왔습니다.' : '링크 형식을 확인해주세요.')),
      );
    }
  }

  void _addPathPoint(Offset localPosition, Size size, AppState state) {
    final selectedSlotId = _selectedSlotId;
    if (selectedSlotId == null) {
      return;
    }
    final x = (localPosition.dx / size.width).clamp(0.06, 0.94);
    final y = (localPosition.dy / size.height).clamp(0.08, 0.94);
    final existing = state.movementPaths[selectedSlotId] ?? const <PathPoint>[];
    final next = [...existing, PathPoint(x: x, y: y)];
    ref
        .read(appControllerProvider.notifier)
        .setMovementPath(slotId: selectedSlotId, points: next);
  }

  Future<void> _openAssignSheet(
    BuildContext context,
    AppState state,
    String slotId,
  ) async {
    final slot = state.selectedFormation.slots.firstWhere(
      (it) => it.id == slotId,
    );
    final assignedPlayerIds = state.assignments
        .where((assignment) => assignment.slotId != slotId)
        .map((assignment) => assignment.playerId)
        .whereType<String>()
        .toSet();
    final selectablePlayers = state.players
        .where((player) => !assignedPlayerIds.contains(player.id))
        .toList();
    final preferredPlayers = selectablePlayers
        .where(
          (player) =>
              matchesPreferredForSlot(player.preferredPosition, slot.label),
        )
        .toList();
    final otherPlayers = selectablePlayers
        .where(
          (player) =>
              !matchesPreferredForSlot(player.preferredPosition, slot.label),
        )
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final hasPlayers = selectablePlayers.isNotEmpty;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.82,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.route_outlined),
                  title: const Text('경로 편집 모드 시작'),
                  onTap: () {
                    setState(() {
                      _selectedSlotId = slotId;
                      _pathEditMode = true;
                    });
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block_outlined),
                  title: const Text('해당 자리 비우기'),
                  onTap: () {
                    ref
                        .read(appControllerProvider.notifier)
                        .assignPlayerToSlot(slotId: slotId, playerId: null);
                    Navigator.pop(context);
                  },
                ),
                const Divider(height: 1),
                if (!hasPlayers)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('배정 가능한 선수가 없습니다.'),
                  ),
                if (hasPlayers)
                  Expanded(
                    child: ListView(
                      children: [
                        if (preferredPlayers.isNotEmpty) ...[
                          const ListTile(
                            dense: true,
                            title: Text(
                              '선호 포지션 일치',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                        ...preferredPlayers.map(
                          (player) => ListTile(
                            title: Text('${player.number}번 ${player.name}'),
                            subtitle: Text('${player.preferredPosition} · 추천'),
                            onTap: () {
                              ref
                                  .read(appControllerProvider.notifier)
                                  .assignPlayerToSlot(
                                    slotId: slotId,
                                    playerId: player.id,
                                  );
                              Navigator.pop(context);
                            },
                          ),
                        ),
                        if (otherPlayers.isNotEmpty) ...[
                          const ListTile(
                            dense: true,
                            title: Text(
                              '다른 선수',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                        ...otherPlayers.map(
                          (player) => ListTile(
                            title: Text('${player.number}번 ${player.name}'),
                            subtitle: Text(player.preferredPosition),
                            onTap: () {
                              ref
                                  .read(appControllerProvider.notifier)
                                  .assignPlayerToSlot(
                                    slotId: slotId,
                                    playerId: player.id,
                                  );
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<PathPoint> _pathWithStart(
    LineupAssignment assignment,
    List<PathPoint>? path,
  ) {
    final points = <PathPoint>[PathPoint(x: assignment.x, y: assignment.y)];
    if (path != null && path.isNotEmpty) {
      points.addAll(path);
    }
    return points;
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), linePaint);
    canvas.drawCircle(Offset(centerX, centerY), 44, linePaint);
    canvas.drawCircle(
      Offset(centerX, centerY),
      2,
      linePaint..style = PaintingStyle.fill,
    );
    linePaint.style = PaintingStyle.stroke;

    final bottomBox = Rect.fromCenter(
      center: Offset(centerX, size.height - 48),
      width: size.width * 0.58,
      height: 92,
    );
    canvas.drawRect(bottomBox, linePaint);

    final topBox = Rect.fromCenter(
      center: Offset(centerX, 48),
      width: size.width * 0.58,
      height: 92,
    );
    canvas.drawRect(topBox, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.assignments,
    required this.movementPaths,
    required this.selectedSlotId,
    required this.progress,
  });

  final List<LineupAssignment> assignments;
  final Map<String, List<PathPoint>> movementPaths;
  final String? selectedSlotId;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final defaultPaint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final selectedPaint = Paint()
      ..color = Colors.orangeAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (final assignment in assignments) {
      final points = _pathWithStart(
        assignment,
        movementPaths[assignment.slotId],
      );
      if (points.length < 2) {
        continue;
      }
      final paint = assignment.slotId == selectedSlotId
          ? selectedPaint
          : defaultPaint;
      final path = Path()
        ..moveTo(points.first.x * size.width, points.first.y * size.height);
      for (final point in points.skip(1)) {
        path.lineTo(point.x * size.width, point.y * size.height);
      }
      canvas.drawPath(path, paint);

      final marker = _pointAt(points, progress);
      canvas.drawCircle(
        Offset(marker.x * size.width, marker.y * size.height),
        5,
        Paint()..color = paint.color,
      );
    }
  }

  PathPoint _pointAt(List<PathPoint> points, double t) {
    if (points.length == 1) {
      return points.first;
    }
    final segmentCount = points.length - 1;
    final scaled = t * segmentCount;
    final segmentIndex = math.min(segmentCount - 1, scaled.floor());
    final segmentT = scaled - segmentIndex;
    final start = points[segmentIndex];
    final end = points[segmentIndex + 1];
    return PathPoint(
      x: start.x + (end.x - start.x) * segmentT,
      y: start.y + (end.y - start.y) * segmentT,
    );
  }

  List<PathPoint> _pathWithStart(
    LineupAssignment assignment,
    List<PathPoint>? path,
  ) {
    final points = <PathPoint>[PathPoint(x: assignment.x, y: assignment.y)];
    if (path != null && path.isNotEmpty) {
      points.addAll(path);
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.movementPaths != movementPaths ||
        oldDelegate.selectedSlotId != selectedSlotId ||
        oldDelegate.progress != progress;
  }
}
