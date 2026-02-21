import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/positions.dart';
import '../../core/models/player.dart';
import '../state/app_controller.dart';

class PlayersScreen extends ConsumerWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('선수 명단'),
        actions: [
          IconButton(
            tooltip: '샘플 데이터 입력',
            onPressed: () => _confirmLoadSample(context, ref),
            icon: const Icon(Icons.science_outlined),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('오류: $error')),
        data: (data) {
          if (data.players.isEmpty) {
            return const Center(child: Text('선수를 추가해보세요.'));
          }
          return ListView.separated(
            itemCount: data.players.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final player = data.players[index];
              return ListTile(
                title: Text('${player.number}번 ${player.name}'),
                subtitle: Text('선호 포지션: ${player.preferredPosition}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () =>
                          _openPlayerDialog(context, ref, initial: player),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => ref
                          .read(appControllerProvider.notifier)
                          .removePlayer(player.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPlayerDialog(context, ref),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('선수 추가'),
      ),
    );
  }

  Future<void> _confirmLoadSample(BuildContext context, WidgetRef ref) async {
    final shouldLoad = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('샘플 데이터 입력'),
          content: const Text('기존 선수 명단을 포지션별 샘플 데이터로 교체할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('입력'),
            ),
          ],
        );
      },
    );
    if (shouldLoad != true) {
      return;
    }

    await ref.read(appControllerProvider.notifier).loadSamplePlayers();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('샘플 선수 14명을 입력했습니다.')));
    }
  }

  Future<void> _openPlayerDialog(
    BuildContext context,
    WidgetRef ref, {
    Player? initial,
  }) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final numberController = TextEditingController(
      text: initial != null ? initial.number.toString() : '',
    );
    var selectedPosition = normalizePosition(
      initial?.preferredPosition ?? kPreferredPositions.first,
    );
    if (!kPreferredPositions.contains(selectedPosition)) {
      selectedPosition = kPreferredPositions.first;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(initial == null ? '선수 추가' : '선수 수정'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '이름'),
                  ),
                  TextField(
                    controller: numberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '등번호'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPosition,
                    decoration: const InputDecoration(labelText: '선호 포지션'),
                    items: kPreferredPositions
                        .map(
                          (position) => DropdownMenuItem<String>(
                            value: position,
                            child: Text(position),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        selectedPosition = value;
                      });
                    },
                  ),
                ],
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
      },
    );

    if (result != true) {
      return;
    }

    final name = nameController.text.trim();
    final number = int.tryParse(numberController.text.trim());
    final position = selectedPosition;

    if (name.isEmpty || number == null || position.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이름, 등번호, 포지션을 모두 입력하세요.')),
        );
      }
      return;
    }

    final notifier = ref.read(appControllerProvider.notifier);
    if (initial == null) {
      await notifier.addPlayer(
        name: name,
        number: number,
        preferredPosition: position,
      );
      return;
    }
    await notifier.updatePlayer(
      playerId: initial.id,
      name: name,
      number: number,
      preferredPosition: position,
    );
  }
}
