import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dfet_coach/theme/admin_theme.dart';
import '../../services/content_service.dart';

final contentServiceProvider = Provider((ref) => ContentService());

final workoutsStreamProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(contentServiceProvider).getWorkoutsStream();
});

class WorkoutManagerPage extends ConsumerWidget {
  const WorkoutManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '운동 DB 관리',
                  style: AdminTheme.displayLarge,
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEditDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('운동 추가'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminColors.border),
                ),
                child: workoutsAsync.when(
                  data: (workouts) => workouts.isEmpty
                      ? Center(
                          child: Text('등록된 운동이 없습니다.',
                              style: AdminTheme.bodyMedium))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: workouts.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white10),
                          itemBuilder: (context, index) {
                            final workout = workouts[index];
                            return ListTile(
                              title: Text(workout['name'] ?? '이름 없음',
                                  style: AdminTheme.titleMedium),
                              subtitle: Text(
                                '${workout['part'] ?? '-'} | ${workout['difficulty'] ?? '-'}',
                                style: AdminTheme.bodyMedium,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: AdminTheme.secondary),
                                    onPressed: () => _showEditDialog(
                                        context, ref,
                                        workout: workout),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: AdminTheme.error),
                                    onPressed: () => _deleteWorkout(
                                        context, ref, workout['id']),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(
                      child: Text('Error: $e',
                          style: const TextStyle(color: Colors.red))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? workout}) {
    final nameController = TextEditingController(text: workout?['name']);
    final partController = TextEditingController(text: workout?['part']);
    final difficultyController =
        TextEditingController(text: workout?['difficulty']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text(workout == null ? '운동 추가' : '운동 수정',
            style: AdminTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: '운동 이름',
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: partController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: '운동 부위',
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
            TextField(
              controller: difficultyController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: '난이도',
                  labelStyle: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'name': nameController.text,
                'part': partController.text,
                'difficulty': difficultyController.text,
              };

              if (workout == null) {
                await ref.read(contentServiceProvider).addWorkout(data);
              } else {
                await ref
                    .read(contentServiceProvider)
                    .updateWorkout(workout['id'], data);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _deleteWorkout(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text('삭제 확인', style: AdminTheme.titleLarge),
        content: Text('정말 삭제하시겠습니까?', style: AdminTheme.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.error),
            onPressed: () async {
              await ref.read(contentServiceProvider).deleteWorkout(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
