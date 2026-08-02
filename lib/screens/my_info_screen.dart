import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/user_state.dart';
import '../theme/tokens.dart';

class MyInfoScreen extends ConsumerWidget {
  const MyInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(userProfileProvider);

    return Container(
      color: context.wellness.bgRoot,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios,
                color: context.wellness.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '내 정보',
            style: GoogleFonts.outfit(
                color: context.wellness.textPrimary,
                fontWeight: FontWeight.bold),
          ),
        ),
        body: userProfileAsync.when(
          data: (profile) {
            if (profile == null) {
              return Center(
                  child: Text('프로필 정보를 불러올 수 없습니다.',
                      style: TextStyle(color: context.wellness.textPrimary)));
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildInfoCard(
                  context,
                  title: '기본 정보',
                  children: [
                    _buildInfoRow(context, '이름', profile.displayName ?? '사용자'),
                    _buildInfoRow(context, '이메일', profile.email ?? '-'),
                    _buildInfoRow(context, '가입일', profile.createdAt != null ? profile.createdAt.toString().split(' ')[0] : '-'),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  context,
                  title: '신체 정보',
                  children: [
                    _buildInfoRow(context, '성별', profile.gender == 'Male' ? '남성' : (profile.gender == 'Female' ? '여성' : '-')),
                    _buildInfoRow(context, '나이', '${profile.age ?? -1}세'),
                    _buildInfoRow(context, '키', '${profile.height?.toInt() ?? -1}cm'),
                    _buildInfoRow(context, '몸무게', '${profile.weight?.toInt() ?? -1}kg'),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  context,
                  title: '목표 및 활동',
                  children: [
                    _buildInfoRow(context, '목표', profile.goal ?? '-'),
                    _buildInfoRow(context, '활동량', profile.activityLevel ?? '-'),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
              child: Text('Error: $err',
                  style: TextStyle(color: context.wellness.textPrimary))),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.wellness.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.wellness.borderSubtle),
        boxShadow: WellnessShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: PremiumColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: context.wellness.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.wellness.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
