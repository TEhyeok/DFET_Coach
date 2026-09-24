import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/app_card.dart';

class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      appBar: AppBar(
        title: const Text('알림'),
        backgroundColor: context.wellness.bgRoot,
        surfaceTintColor: Colors.transparent,
      ),
      body: const SafeArea(
        top: false,
        child: NotificationCenterScreen(),
      ),
    );
  }
}

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late Future<List<_HealthNotice>> _notices;

  @override
  void initState() {
    super.initState();
    _notices = _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final next = _load();
        setState(() => _notices = next);
        await next;
      },
      child: FutureBuilder<List<_HealthNotice>>(
        future: _notices,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _NotificationState(
              icon: Icons.sync_problem_rounded,
              title: '알림을 불러오지 못했어요',
              message: '화면을 아래로 당겨 다시 시도해 주세요.',
            );
          }
          final notices = snapshot.data ?? const [];
          if (notices.isEmpty) {
            return const _NotificationState(
              icon: Icons.notifications_none_rounded,
              title: '새 알림이 없어요',
              message: '검사 결과나 코칭 요청 상태가 변경되면 여기에 모아서 보여드려요.',
            );
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: notices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _NotificationTile(
              notice: notices[index],
            ),
          );
        },
      ),
    );
  }

  Future<List<_HealthNotice>> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('requests').where('userId', isEqualTo: uid).limit(30).get(),
      db
          .collection('gutReports')
          .where('userId', isEqualTo: uid)
          .limit(20)
          .get(),
      db
          .collection('bloodReports')
          .where('userId', isEqualTo: uid)
          .limit(20)
          .get(),
      db
          .collection('healthSnapshots')
          .where('userId', isEqualTo: uid)
          .limit(20)
          .get(),
    ]);

    final notices = <_HealthNotice>[];
    for (final document in results[0].docs) {
      final data = document.data();
      final status = data['status'] as String? ?? 'pending';
      notices.add(_HealthNotice(
        title: '코칭 요청 · ${_requestStatus(status)}',
        message: (data['adminFeedback'] as String?)?.trim().isNotEmpty == true
            ? data['adminFeedback'] as String
            : data['title'] as String? ?? '접수한 요청의 처리 상태를 확인하세요.',
        occurredAt: _date(data['updatedAt'] ?? data['createdAt']),
        route: '/home/myPage/requests',
        icon: Icons.forum_outlined,
        color: AppColors.info,
      ));
    }
    for (final document in results[1].docs) {
      final data = document.data();
      notices.add(_HealthNotice(
        title: '장 건강 결과가 도착했어요',
        message: _reportMessage(data),
        occurredAt: _date(data['reportedAt'] ?? data['updatedAt']),
        route: '/gut/${document.id}',
        icon: Icons.bubble_chart_outlined,
        color: AppColors.success,
      ));
    }
    for (final document in results[2].docs) {
      final data = document.data();
      notices.add(_HealthNotice(
        title: '혈액 POCT 결과가 도착했어요',
        message: _reportMessage(data),
        occurredAt: _date(data['reportedAt'] ?? data['updatedAt']),
        route: '/blood/${document.id}',
        icon: Icons.water_drop_outlined,
        color: AppColors.danger,
      ));
    }
    for (final document in results[3].docs) {
      final data = document.data();
      notices.add(_HealthNotice(
        title: '4축 통합 인사이트가 갱신됐어요',
        message: _snapshotMessage(data),
        occurredAt: _date(data['asOf'] ?? data['createdAt']),
        route: '/insights/${document.id}',
        icon: Icons.radar_rounded,
        color: AppColors.brandPrimary,
      ));
    }
    notices.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return notices.take(60).toList(growable: false);
  }

  static String _requestStatus(String status) => switch (status) {
        'in_progress' || 'inProgress' => '처리 중',
        'completed' => '답변 완료',
        'rejected' => '반려',
        _ => '접수 완료',
      };

  static String _reportMessage(Map<String, dynamic> data) {
    final overall = data['overall'];
    if (overall is Map<String, dynamic>) {
      return overall['label'] as String? ?? '상세 리포트를 확인해 보세요.';
    }
    return '상세 리포트를 확인해 보세요.';
  }

  static String _snapshotMessage(Map<String, dynamic> data) {
    final missing = data['missingAxes'];
    if (missing is List && missing.isNotEmpty) {
      return '현재 ${4 - missing.length}/4축 데이터가 연결되었어요.';
    }
    return '운동·식단·장·혈액 데이터를 함께 확인하세요.';
  }

  static DateTime _date(dynamic value) => value is Timestamp
      ? value.toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notice});

  final _HealthNotice notice;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(notice.route),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: notice.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(notice.icon, color: notice.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: AppTextStyles.body.copyWith(
                    color: context.wellness.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  notice.message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: context.wellness.textSecondary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  DateFormat('yyyy.MM.dd HH:mm').format(notice.occurredAt),
                  style: AppTextStyles.caption.copyWith(
                    color: context.wellness.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: context.wellness.textTertiary),
        ],
      ),
    );
  }
}

class _NotificationState extends StatelessWidget {
  const _NotificationState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 96),
        Icon(icon, size: 58, color: context.wellness.textTertiary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: AppTextStyles.h3.copyWith(color: context.wellness.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall.copyWith(
            color: context.wellness.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _HealthNotice {
  const _HealthNotice({
    required this.title,
    required this.message,
    required this.occurredAt,
    required this.route,
    required this.icon,
    required this.color,
  });

  final String title;
  final String message;
  final DateTime occurredAt;
  final String route;
  final IconData icon;
  final Color color;
}
