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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [PremiumColors.backgroundStart, PremiumColors.backgroundEnd],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '내 정보',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: userProfileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('프로필 정보를 불러올 수 없습니다.', style: TextStyle(color: Colors.white)));
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildInfoCard(
                  title: '기본 정보',
                  children: [
                    _buildInfoRow('이름', profile.displayName ?? '사용자'),
                    _buildInfoRow('이메일', profile.email ?? '-'),
                    _buildInfoRow('가입일', profile.createdAt != null ? profile.createdAt.toString().split(' ')[0] : '-'),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  title: '신체 정보',
                  children: [
                    _buildInfoRow('성별', profile.gender == 'Male' ? '남성' : (profile.gender == 'Female' ? '여성' : '-')),
                    _buildInfoRow('나이', '${profile.age ?? -1}세'),
                    _buildInfoRow('키', '${profile.height?.toInt() ?? -1}cm'),
                    _buildInfoRow('몸무게', '${profile.weight?.toInt() ?? -1}kg'),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  title: '목표 및 활동',
                  children: [
                    _buildInfoRow('목표', profile.goal ?? '-'),
                    _buildInfoRow('활동량', profile.activityLevel ?? '-'),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
