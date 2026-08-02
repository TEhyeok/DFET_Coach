import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/tokens.dart';
import '../state/auth_state.dart';
import '../widgets/app_card.dart';
import '../utils/responsive_layout.dart';
import 'create_request_screen.dart';

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Center(
          child: Text('요청 내역을 보려면 로그인해주세요',
              style: TextStyle(color: context.wellness.textPrimary)));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            CupertinoPageRoute(
                builder: (context) => const CreateRequestScreen()),
          );
        },
        backgroundColor: PremiumColors.primary,
        icon: const Icon(CupertinoIcons.add),
        label: const Text('새 요청'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('requests')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('오류: ${snapshot.error}',
                    style: TextStyle(color: context.wellness.textPrimary)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.doc_text_search,
                      size: 64, color: context.wellness.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    '아직 요청 내역이 없습니다',
                    style: TextStyle(
                        color: context.wellness.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '아래 버튼을 눌러\n자세 분석이나 식단 피드백을 요청해보세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: context.wellness.textTertiary, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView.builder(
                padding: ResponsiveLayout.pagePadding(context),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'newRequest';
                  final createdAt =
                      (data['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime.now();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatusChip(status),
                              Text(
                                DateFormat('MMM d, yyyy').format(createdAt),
                                style: TextStyle(
                                  color: context.wellness.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            data['title'] ?? '제목 없음',
                            style: TextStyle(
                              color: context.wellness.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['description'] ?? '',
                            style: TextStyle(
                                color: context.wellness.textSecondary,
                                fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (data['adminFeedback'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PremiumColors.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: PremiumColors.primary
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.chat_bubble_2_fill,
                                        size: 16,
                                        color: PremiumColors.primary,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '코치 피드백',
                                        style: TextStyle(
                                          color: PremiumColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    data['adminFeedback'],
                                    style: TextStyle(
                                        color: context.wellness.textPrimary,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'newRequest':
        color = Colors.blue;
        label = '대기중';
        break;
      case 'inProgress':
        color = Colors.orange;
        label = '진행중';
        break;
      case 'completed':
        color = Colors.green;
        label = '완료됨';
        break;
      case 'rejected':
        color = Colors.red;
        label = '반려됨';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
