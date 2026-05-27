import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/admin_theme.dart';
import '../../services/admin_auth_service.dart';
import '../../models/admin_profile.dart';

final pendingAdminsProvider = StreamProvider<List<AdminProfile>>((ref) {
  return AdminAuthService().getPendingAdminsStream();
});

class AdminHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AdminHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final backgroundColor = isLight ? AdminTheme.backgroundLight : AdminTheme.background;
    final borderColor = isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.05);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: backgroundColor.withOpacity(0.5),
            border: Border(
              bottom: BorderSide(
                color: borderColor,
              ),
            ),
          ),
          child: Row(
            children: [
              // Breadcrumbs or Page Title could go here
              Text(
                'Overview',
                style: AdminTheme.titleLarge.copyWith(
                  color: isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite,
                ),
              ),
              const Spacer(),
              
              // Search Bar
              Container(
                width: 300,
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isLight ? AdminTheme.surfaceLight : AdminTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: isLight ? AdminTheme.textSecondaryLight : AdminTheme.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        style: AdminTheme.bodyMedium.copyWith(
                          color: isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: AdminTheme.bodyMedium.copyWith(
                            color: isLight ? AdminTheme.textSecondaryLight : AdminTheme.textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Actions
              _buildNotificationButton(context, ref, isLight),
              const SizedBox(width: 12),
              _buildIconButton(Icons.settings_outlined, isLight),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton(BuildContext context, WidgetRef ref, bool isLight) {
    final pendingAdminsAsync = ref.watch(pendingAdminsProvider);
    final backgroundColor = isLight ? AdminTheme.surfaceLight : AdminTheme.surface;
    final borderColor = isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.05);
    final iconColor = isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite;

    return pendingAdminsAsync.when(
      data: (pendingAdmins) {
        final hasNotifications = pendingAdmins.isNotEmpty;
        
        return PopupMenuButton<String>(
          offset: const Offset(0, 50),
          color: isLight ? Colors.white : AdminTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor),
          ),
          itemBuilder: (context) {
            if (!hasNotifications) {
              return [
                const PopupMenuItem(
                  enabled: false,
                  child: Text('새로운 알림이 없습니다.'),
                ),
              ];
            }
            return [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  '알림 (${pendingAdmins.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isLight ? Colors.black : Colors.white,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              ...pendingAdmins.map((admin) => PopupMenuItem(
                value: '/admin/admins',
                child: Row(
                  children: [
                    const Icon(Icons.person_add, color: AdminTheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '새 관리자 승인 요청',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isLight ? Colors.black : Colors.white,
                            ),
                          ),
                          Text(
                            '${admin.displayName} (${admin.email})',
                            style: TextStyle(
                              fontSize: 12,
                              color: isLight ? Colors.grey[600] : Colors.grey[400],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ];
          },
          onSelected: (value) {
            context.go(value);
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_outlined, color: iconColor, size: 20),
                if (hasNotifications)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AdminTheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => _buildIconButton(Icons.notifications_outlined, isLight),
      error: (_, __) => _buildIconButton(Icons.notifications_outlined, isLight),
    );
  }

  Widget _buildIconButton(IconData icon, bool isLight) {
    final backgroundColor = isLight ? AdminTheme.surfaceLight : AdminTheme.surface;
    final borderColor = isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.05);
    final iconColor = isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(80);
}
