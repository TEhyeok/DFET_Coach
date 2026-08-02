import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dfet_coach/theme/admin_theme.dart';
import 'workout_manager_page.dart'; // Reuse provider

final foodsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(contentServiceProvider).getFoodsStream();
});

class FoodManagerPage extends ConsumerWidget {
  const FoodManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(foodsStreamProvider);

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
                  '식단 DB 관리',
                  style: AdminTheme.displayLarge,
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEditDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('음식 추가'),
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
                child: foodsAsync.when(
                  data: (foods) => foods.isEmpty
                      ? Center(
                          child: Text('등록된 음식이 없습니다.',
                              style: AdminTheme.bodyMedium))
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: foods.length,
                          separatorBuilder: (_, __) =>
                              const Divider(color: Colors.white10),
                          itemBuilder: (context, index) {
                            final food = foods[index];
                            return ListTile(
                              title: Text(food['name'] ?? '이름 없음',
                                  style: AdminTheme.titleMedium),
                              subtitle: Text(
                                '${food['calories']}kcal | P:${food['protein']} C:${food['carbs']} F:${food['fat']}',
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
                                        food: food),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: AdminTheme.error),
                                    onPressed: () =>
                                        _deleteFood(context, ref, food['id']),
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
      {Map<String, dynamic>? food}) {
    final nameController = TextEditingController(text: food?['name']);
    final calController =
        TextEditingController(text: food?['calories']?.toString());
    final proteinController =
        TextEditingController(text: food?['protein']?.toString());
    final carbsController =
        TextEditingController(text: food?['carbs']?.toString());
    final fatController = TextEditingController(text: food?['fat']?.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: Text(food == null ? '음식 추가' : '음식 수정',
            style: AdminTheme.titleLarge),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: '음식 이름',
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
              TextField(
                controller: calController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: '칼로리 (kcal)',
                    labelStyle: TextStyle(color: Colors.white70)),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: '단백질 (g)',
                          labelStyle: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: '탄수화물 (g)',
                          labelStyle: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: '지방 (g)',
                          labelStyle: TextStyle(color: Colors.white70)),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                'calories': int.tryParse(calController.text) ?? 0,
                'protein': double.tryParse(proteinController.text) ?? 0,
                'carbs': double.tryParse(carbsController.text) ?? 0,
                'fat': double.tryParse(fatController.text) ?? 0,
              };

              if (food == null) {
                await ref.read(contentServiceProvider).addFood(data);
              } else {
                await ref
                    .read(contentServiceProvider)
                    .updateFood(food['id'], data);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _deleteFood(BuildContext context, WidgetRef ref, String id) {
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
              await ref.read(contentServiceProvider).deleteFood(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
