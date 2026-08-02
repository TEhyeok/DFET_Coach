import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/admin_theme.dart';
import '../../state/auth_state.dart';
import '../../widgets/dfet_logo_mark.dart';

class AdminSidebar extends ConsumerWidget {
  final String currentPage;

  const AdminSidebar({super.key, required this.currentPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final surfaceColor = isLight ? AdminTheme.surfaceLight : AdminTheme.surface;
    final borderColor = isLight
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.05);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: surfaceColor.withValues(alpha: 0.7),
            border: Border(
              right: BorderSide(
                color: borderColor,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildLogo(context),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildMenuSection(context, 'MENU'),
                    _buildMenuItem(
                      context,
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      id: 'dashboard',
                      onTap: () => context.go('/admin'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.inbox_rounded,
                      label: 'Requests',
                      id: 'requests',
                      onTap: () => context.go('/admin/requests'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.people_alt_rounded,
                      label: 'Users',
                      id: 'users',
                      onTap: () => context.go('/admin/users'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.analytics_rounded,
                      label: 'Analytics',
                      id: 'analytics',
                      onTap: () => context.go('/admin/analytics'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.library_books_rounded,
                      label: 'Content',
                      id: 'content',
                      onTap: () => context.go('/admin/content'),
                    ),
                    const SizedBox(height: 24),
                    _buildMenuSection(context, 'SYSTEM'),
                    _buildMenuItem(
                      context,
                      icon: Icons.settings_rounded,
                      label: 'Settings',
                      id: 'settings',
                      onTap: () => context.go('/admin/settings'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),
                    _buildMenuItem(
                      context,
                      icon: Icons.admin_panel_settings_rounded,
                      label: 'Admins',
                      id: 'admins',
                      onTap: () => context.go('/admin/admins'),
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      id: 'logout',
                      onTap: () {
                        final isLight =
                            Theme.of(context).brightness == Brightness.light;
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: isLight
                                ? Colors.white
                                : const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: Text(
                              'Logout',
                              style: AdminTheme.titleLarge.copyWith(
                                color: isLight ? Colors.black : Colors.white,
                              ),
                            ),
                            content: Text(
                              'Are you sure you want to logout?',
                              style: AdminTheme.bodyMedium.copyWith(
                                color:
                                    isLight ? Colors.black87 : Colors.white70,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: isLight
                                      ? Colors.grey[600]
                                      : AdminTheme.textSecondary,
                                ),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context); // Close dialog
                                  try {
                                    // Actual Logout Logic
                                    final authService =
                                        ref.read(authServiceProvider);
                                    await authService.signOut();

                                    if (context.mounted) {
                                      // GoRouter redirect will handle the navigation to /login
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                              'Logged out successfully'),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: AdminTheme.success,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text('Logout failed: $e'),
                                          backgroundColor: AdminTheme.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminTheme.error,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );
                      },
                      isDestructive: true,
                    ),
                  ],
                ),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Container(
      height: 80,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const DfetLogoMark(
            size: 36,
            showShadow: false,
          ),
          const SizedBox(width: 12),
          Text(
            'D-FET',
            style: AdminTheme.titleLarge.copyWith(
              letterSpacing: 1.2,
              color:
                  isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(BuildContext context, String title) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        title,
        style: AdminTheme.bodyMedium.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color:
              isLight ? AdminTheme.textDisabledLight : AdminTheme.textDisabled,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String id,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isSelected = currentPage == id;

    final defaultColor =
        isLight ? AdminTheme.textSecondaryLight : AdminTheme.textSecondary;
    final selectedTextColor =
        isLight ? AdminTheme.primary : AdminTheme.textWhite;

    final color = isDestructive
        ? AdminTheme.error
        : (isSelected ? selectedTextColor : defaultColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: isLight
            ? Colors.black.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.05),
        child: Container(
          height: 48,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: isSelected
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AdminTheme.primary.withValues(alpha: isLight ? 0.1 : 0.2),
                      AdminTheme.primary
                          .withValues(alpha: isLight ? 0.05 : 0.05),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AdminTheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                )
              : null,
          child: Row(
            children: [
              Icon(icon,
                  size: 20, color: isSelected ? AdminTheme.primary : color),
              const SizedBox(width: 12),
              Text(
                label,
                style: AdminTheme.bodyMedium.copyWith(
                  color: isSelected ? AdminTheme.textWhite : color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AdminTheme.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textColor =
        isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite;
    final subTextColor =
        isLight ? AdminTheme.textSecondaryLight : AdminTheme.textSecondary;
    final highlightColor = isLight
        ? AdminTheme.surfaceHighlightLight
        : AdminTheme.surfaceHighlight;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: highlightColor,
            child: Icon(Icons.person, size: 16, color: subTextColor),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Admin User',
                style: AdminTheme.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Super Admin',
                style: AdminTheme.bodyMedium
                    .copyWith(fontSize: 12, color: subTextColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
