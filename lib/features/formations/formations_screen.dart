import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/formation.dart';
import '../../core/models/app_state.dart';
import '../state/app_controller.dart';

class FormationsScreen extends ConsumerWidget {
  const FormationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('포메이션 선택')),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('오류: $error')),
        data: (data) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment<String>(
                        value: TacticalPhase.attack,
                        label: Text('공격 포메이션'),
                      ),
                      ButtonSegment<String>(
                        value: TacticalPhase.defense,
                        label: Text('수비 포메이션'),
                      ),
                    ],
                    selected: {data.activePhase},
                    onSelectionChanged: (selected) {
                      if (selected.isEmpty) {
                        return;
                      }
                      ref
                          .read(appControllerProvider.notifier)
                          .setActivePhase(selected.first);
                    },
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: FormationTemplate.defaults.length,
                  itemBuilder: (context, index) {
                    final formation = FormationTemplate.defaults[index];
                    final selected = formation.id == data.selectedFormationId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          formation.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: formation.slots
                                .map((slot) => Chip(label: Text(slot.label)))
                                .toList(),
                          ),
                        ),
                        trailing: selected
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : null,
                        onTap: () => ref
                            .read(appControllerProvider.notifier)
                            .selectFormation(formation.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
