import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.wellness.bgRoot,
      appBar: AppBar(
        backgroundColor: context.wellness.bgRoot,
        surfaceTintColor: Colors.transparent,
        title: const Text('프리미엄 멤버십'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 64,
              color: context.wellness.primary,
            ),
            const SizedBox(height: 20),
            Text(
              '멤버십 판매 준비 중',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.wellness.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '스토어 상품 등록과 서버 영수증 검증이 완료되기 전에는 결제와 프리미엄 권한 부여를 제공하지 않습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.wellness.textSecondary,
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),
            _StatusCard(
              icon: Icons.storefront_outlined,
              title: '스토어 상품',
              description: 'App Store Connect·Play Console 승인 상품 연결 필요',
            ),
            const SizedBox(height: 12),
            _StatusCard(
              icon: Icons.verified_user_outlined,
              title: '구매 검증',
              description: 'Firebase Functions 서버 영수증 검증과 만료 처리 필요',
            ),
            const SizedBox(height: 12),
            _StatusCard(
              icon: Icons.notifications_active_outlined,
              title: '구독 상태 동기화',
              description: '갱신·취소·환불 웹훅 검증 후 활성화 예정',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.wellness.bgSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.wellness.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: context.wellness.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '현재 화면에서는 결제 요청이나 임의 가격 표시가 발생하지 않습니다.',
                      style: TextStyle(
                        color: context.wellness.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.wellness.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.wellness.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.wellness.primarySubtle,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: context.wellness.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.wellness.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: context.wellness.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: context.wellness.bgSubtle,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '대기',
              style: TextStyle(
                color: context.wellness.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
