import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/request_item.dart';
import '../services/request_service.dart';
import '../widgets/request_card.dart';
import '../../theme/admin_theme.dart';

final requestsStreamProvider = StreamProvider<List<RequestItem>>((ref) {
  final service = RequestService();
  return service.getRequestsStream();
});

class RequestsPage extends ConsumerWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(requestsStreamProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Request Management',
          style: AdminTheme.displaySmall.copyWith(
            color: isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Generate Mock Data',
            onPressed: () {
              RequestService().createMockRequests();
            },
          ),
        ],
      ),
      body: requestsAsync.when(
        data: (requests) => _buildKanbanBoard(context, requests),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error: $error', style: const TextStyle(color: AdminTheme.error)),
        ),
      ),
    );
  }

  Widget _buildKanbanBoard(BuildContext context, List<RequestItem> requests) {
    final newRequests = requests.where((r) => r.status == RequestStatus.newRequest).toList();
    final inProgressRequests = requests.where((r) => r.status == RequestStatus.inProgress).toList();
    final completedRequests = requests.where((r) => r.status == RequestStatus.completed).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColumn(context, 'New Requests', newRequests, AdminTheme.error),
          const SizedBox(width: 24),
          _buildColumn(context, 'In Progress', inProgressRequests, AdminTheme.warning),
          const SizedBox(width: 24),
          _buildColumn(context, 'Completed', completedRequests, AdminTheme.success),
        ],
      ),
    );
  }

  Widget _buildColumn(
    BuildContext context,
    String title,
    List<RequestItem> items,
    Color color,
  ) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    return Container(
      width: 350,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: AdminTheme.titleMedium.copyWith(
                  color: isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isLight ? AdminTheme.textSecondaryLight : AdminTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Text(
                'No requests',
                style: AdminTheme.bodyMedium.copyWith(
                  color: isLight ? AdminTheme.textDisabledLight : AdminTheme.textDisabled,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                return RequestCard(
                  request: item,
                  onTap: () {
                    // TODO: Navigate to detail page
                    // context.go('/admin/requests/${item.id}');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Clicked on ${item.title}')),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
