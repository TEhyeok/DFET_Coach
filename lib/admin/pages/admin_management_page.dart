import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/admin_auth_service.dart';
import '../../models/admin_profile.dart';
import '../../theme/admin_theme.dart';

class AdminManagementPage extends ConsumerStatefulWidget {
  const AdminManagementPage({super.key});

  @override
  ConsumerState<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends ConsumerState<AdminManagementPage> {
  final AdminAuthService _adminAuthService = AdminAuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '관리자 승인 관리',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AdminColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '새로운 관리자 요청을 승인하거나 거부할 수 있습니다.',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AdminColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            
            Expanded(
              child: StreamBuilder<List<AdminProfile>>(
                stream: _adminAuthService.getPendingAdminsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('오류 발생: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final admins = snapshot.data ?? [];

                  if (admins.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: AdminColors.textSecondary),
                          const SizedBox(height: 16),
                          Text(
                            '승인 대기 중인 요청이 없습니다.',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: AdminColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: admins.length,
                    itemBuilder: (context, index) {
                      final admin = admins[index];
                      return _buildAdminCard(admin);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(AdminProfile admin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminColors.primary.withOpacity(0.1),
            child: Text(
              admin.displayName.isNotEmpty ? admin.displayName[0] : '?',
              style: TextStyle(color: AdminColors.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin.displayName,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AdminColors.textPrimary,
                  ),
                ),
                Text(
                  admin.email,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AdminColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '요청일: ${DateFormat('yyyy-MM-dd HH:mm').format(admin.createdAt)}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AdminColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _rejectAdmin(admin),
                style: TextButton.styleFrom(
                  foregroundColor: AdminColors.error,
                ),
                child: const Text('거부'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _approveAdmin(admin),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('승인'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveAdmin(AdminProfile admin) async {
    try {
      await _adminAuthService.approveAdmin(admin.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${admin.displayName}님을 승인했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('승인 실패: $e')),
        );
      }
    }
  }

  Future<void> _rejectAdmin(AdminProfile admin) async {
    try {
      await _adminAuthService.rejectAdmin(admin.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${admin.displayName}님의 요청을 거부했습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('거부 실패: $e')),
        );
      }
    }
  }
}
