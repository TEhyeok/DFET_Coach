import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../state/user_state.dart';
import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../utils/ios_navigation.dart';
import '../utils/responsive_layout.dart';
import '../widgets/app_card.dart';
import '../widgets/ios_adaptive_sheet.dart';
import 'member_soap_notes_screen.dart';
import 'my_info_screen.dart';
import 'community/community_screen.dart';
import 'settings_screen.dart';
import 'tickets.dart';

class IOSProfileScreen extends ConsumerWidget {
  const IOSProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ResponsiveConstrainedBox(
          maxWidth: 820,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                padding: const EdgeInsets.all(14),
                child: profileAsync.when(
                  data: (profile) => Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color:
                              context.wellness.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          CupertinoIcons.person_crop_circle_fill,
                          color: context.wellness.primary,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? '사용자',
                              style: AppTextStyles.h3.copyWith(
                                  color: context.wellness.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile?.email ?? '계정 정보 없음',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.wellness.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  loading: () =>
                      const Center(child: CupertinoActivityIndicator()),
                  error: (_, __) => Text(
                    '프로필 정보를 불러올 수 없습니다',
                    style: AppTextStyles.body
                        .copyWith(color: context.wellness.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IOSActionRow(
                icon: CupertinoIcons.person_2,
                title: '커뮤니티',
                subtitle: '운동·식단 공유 피드',
                color: AppColors.brandPrimary,
                onPressed: () => Navigator.of(context).push(
                  adaptivePageRoute(
                    builder: (context) => const CommunityScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IOSActionRow(
                icon: CupertinoIcons.person,
                title: '프로필',
                subtitle: '신체 정보와 목표',
                onPressed: () => Navigator.of(context).push(
                  adaptivePageRoute(
                    builder: (context) => const MyInfoScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IOSActionRow(
                icon: CupertinoIcons.chat_bubble_2,
                title: '요청',
                subtitle: '코치 피드백 내역',
                color: AppColors.info,
                onPressed: () => Navigator.of(context).push(
                  adaptivePageRoute(
                    builder: (context) => const TicketsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IOSActionRow(
                icon: CupertinoIcons.doc_text,
                title: 'SOAP 노트',
                subtitle: '트레이너가 공유한 평가와 관리 계획',
                color: AppColors.success,
                onPressed: () => Navigator.of(context).push(
                  adaptivePageRoute(
                    builder: (context) => const MemberSoapNotesScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              IOSActionRow(
                icon: CupertinoIcons.heart_circle,
                title: '케어 유형',
                subtitle: '운동·식단, 장 건강, 통합 케어 선택',
                color: AppColors.brandPrimary,
                onPressed: () => context.push('/home/myPage/careType'),
              ),
              const SizedBox(height: 8),
              IOSActionRow(
                icon: CupertinoIcons.settings,
                title: '설정',
                subtitle: '알림, 구독, 계정',
                color: AppColors.accentGold,
                onPressed: () => Navigator.of(context).push(
                  adaptivePageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
