import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_state.dart';
import '../../core/models/movement_path.dart';
import '../../data/app_repository.dart';
import '../../data/local_storage.dart';

final localStorageProvider = Provider<LocalStorage>((ref) {
  return const LocalStorage();
});

final appRepositoryProvider = Provider<AppRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return AppRepository(storage);
});

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends AsyncNotifier<AppState> {
  late final AppRepository _repository;

  @override
  Future<AppState> build() async {
    _repository = ref.read(appRepositoryProvider);
    var state = await _repository.loadState();
    final payload = Uri.base.queryParameters['payload'];
    if (payload != null && payload.isNotEmpty) {
      state = _repository.importFromShareText(state, payload);
      await _repository.saveState(state);
    }
    return state;
  }

  Future<void> addPlayer({
    required String name,
    required int number,
    required String preferredPosition,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.addPlayer(
      current,
      name: name,
      number: number,
      preferredPosition: preferredPosition,
    );
    await _persist(next);
  }

  Future<void> loadSamplePlayers() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.loadSamplePlayers(current);
    await _persist(next);
  }

  Future<void> updatePlayer({
    required String playerId,
    required String name,
    required int number,
    required String preferredPosition,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.updatePlayer(
      current,
      playerId: playerId,
      name: name,
      number: number,
      preferredPosition: preferredPosition,
    );
    await _persist(next);
  }

  Future<void> removePlayer(String playerId) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.removePlayer(current, playerId);
    await _persist(next);
  }

  Future<void> selectFormation(String formationId) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.selectFormation(current, formationId);
    await _persist(next);
  }

  Future<void> setActivePhase(String phase) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.setActivePhase(current, phase);
    await _persist(next);
  }

  Future<void> assignPlayerToSlot({
    required String slotId,
    required String? playerId,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.assignPlayerToSlot(
      current,
      slotId: slotId,
      playerId: playerId,
    );
    await _persist(next);
  }

  Future<void> moveSlot({
    required String slotId,
    required double x,
    required double y,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.moveSlot(current, slotId: slotId, x: x, y: y);
    await _persist(next);
  }

  Future<void> setCoachNote(String coachNote) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.setCoachNote(current, coachNote);
    await _persist(next);
  }

  Future<void> setMovementPath({
    required String slotId,
    required List<PathPoint> points,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.setMovementPath(
      current,
      slotId: slotId,
      points: points,
    );
    await _persist(next);
  }

  Future<void> clearMovementPath(String slotId) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.clearMovementPath(current, slotId);
    await _persist(next);
  }

  Future<void> clearCurrentFormationPaths() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.clearCurrentFormationPaths(current);
    await _persist(next);
  }

  Future<void> replaceTransitionMapping({
    required String fromFormationId,
    required String toFormationId,
    required Map<String, String> mapping,
  }) async {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = _repository.replaceTransitionMapping(
      current,
      fromFormationId: fromFormationId,
      toFormationId: toFormationId,
      mapping: mapping,
    );
    await _persist(next);
  }

  Map<String, String> getTransitionMapping({
    required String fromFormationId,
    required String toFormationId,
  }) {
    final current = state.value;
    if (current == null) {
      return const {};
    }
    return _repository.getTransitionMapping(
      current,
      fromFormationId: fromFormationId,
      toFormationId: toFormationId,
    );
  }

  String? buildShareUrl() {
    final current = state.value;
    if (current == null) {
      return null;
    }
    const configuredBaseUrl = String.fromEnvironment('WEB_SHARE_BASE_URL');
    final baseUri = configuredBaseUrl.isNotEmpty
        ? Uri.parse(configuredBaseUrl)
        : Uri.base;
    return _repository.buildShareUrl(current, baseUri);
  }

  Future<bool> importFromShareText(String raw) async {
    final current = state.value;
    if (current == null) {
      return false;
    }
    final next = _repository.importFromShareText(current, raw);
    if (identical(current, next)) {
      return false;
    }
    await _persist(next);
    return true;
  }

  Future<void> _persist(AppState next) async {
    state = AsyncData(next);
    await _repository.saveState(next);
  }
}
