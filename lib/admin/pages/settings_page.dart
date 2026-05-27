import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_management_service.dart';

import '../../theme/admin_theme.dart';
import '../../state/theme_provider.dart';

/// 앱 정보 Provider
final appInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

/// Settings 페이지
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Local state for toggles
  bool _notifyNewUser = true;
  bool _dailyReport = false;
  bool _errorAlert = true;
  bool _maskPrivacy = true;
  String _inactiveCriteria = '30일';
  String _autoDeletePolicy = '비활성화';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyNewUser = prefs.getBool('notifyNewUser') ?? true;
      _dailyReport = prefs.getBool('dailyReport') ?? false;
      _errorAlert = prefs.getBool('errorAlert') ?? true;
      _maskPrivacy = prefs.getBool('maskPrivacy') ?? true;
      _inactiveCriteria = prefs.getString('inactiveCriteria') ?? '30일';
      _autoDeletePolicy = prefs.getString('autoDeletePolicy') ?? '비활성화';
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appInfoAsync = ref.watch(appInfoProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: AdminTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your application settings and preferences.',
                    style: AdminTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),

                  // 시스템 설정
                  _buildSectionTitle('System Settings'),
                  const SizedBox(height: 16),
                  _buildSystemSettings(appInfoAsync),
                  const SizedBox(height: 32),

                  // 화면 설정
                  _buildSectionTitle('Appearance'),
                  const SizedBox(height: 16),
                  _buildAppearanceSettings(),
                  const SizedBox(height: 32),

                  // 알림 설정
                  _buildSectionTitle('Notifications'),
                  const SizedBox(height: 16),
                  _buildNotificationSettings(),
                  const SizedBox(height: 32),

                  // 데이터 관리
                  _buildSectionTitle('Data Management'),
                  const SizedBox(height: 16),
                  _buildDataManagement(),
                  const SizedBox(height: 32),

                  // 사용자 관리 정책
                  _buildSectionTitle('User Policies'),
                  const SizedBox(height: 16),
                  _buildUserPolicies(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AdminTheme.titleLarge,
    );
  }

  /// 시스템 설정
  Widget _buildSystemSettings(AsyncValue<PackageInfo> appInfoAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            icon: Icons.info_outline_rounded,
            label: 'App Version',
            value: appInfoAsync.when(
              data: (info) => '${info.version} (${info.buildNumber})',
              loading: () => 'Loading...',
              error: (_, __) => 'Unknown',
            ),
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.cloud_queue_rounded,
            label: 'Firebase Project',
            value: 'dfetmanage',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.storage_rounded,
            label: 'Firestore Region',
            value: 'asia-northeast3 (Seoul)',
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.auto_awesome_rounded,
            label: 'Gemini AI Model',
            value: 'gemini-2.0-flash-exp',
          ),
          _buildDivider(),
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 20, color: AdminTheme.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'API Usage',
                  style: AdminTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.textWhite,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _showFeatureNotAvailableDialog('Firebase Console Link');
                },
                style: TextButton.styleFrom(foregroundColor: AdminTheme.primary),
                child: const Text('Open Console'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AdminTheme.textSecondary),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: AdminTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AdminTheme.textWhite,
            ),
          ),
        ),
        Text(
          value,
          style: AdminTheme.bodyMedium.copyWith(
            color: AdminTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 화면 설정
  Widget _buildAppearanceSettings() {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final isLight = themeMode == ThemeMode.light;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: isLight ? AdminTheme.surfaceLight : AdminTheme.surface,
        opacity: 0.6,
        isLight: isLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme Mode',
                      style: AdminTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isLight ? AdminTheme.textPrimaryLight : AdminTheme.textWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select your preferred interface theme',
                      style: isLight
                          ? AdminTheme.bodyMedium.copyWith(color: AdminTheme.textSecondaryLight)
                          : AdminTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: isLight ? AdminTheme.surfaceHighlightLight : AdminTheme.surfaceHighlight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildThemeOption(
                      icon: Icons.light_mode_rounded,
                      label: 'Light',
                      isSelected: themeMode == ThemeMode.light,
                      onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light),
                      isLight: isLight,
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: isLight ? Colors.black.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                    ),
                    _buildThemeOption(
                      icon: Icons.dark_mode_rounded,
                      label: 'Dark',
                      isSelected: themeMode == ThemeMode.dark,
                      onTap: () => ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark),
                      isLight: isLight,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLight,
  }) {
    final selectedColor = isLight ? AdminTheme.primary : AdminTheme.primary;
    final unselectedColor = isLight ? AdminTheme.textSecondaryLight : AdminTheme.textSecondary;
    final selectedBg = isLight ? AdminTheme.primary.withOpacity(0.1) : AdminTheme.primary.withOpacity(0.2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 알림 설정
  Widget _buildNotificationSettings() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSwitchSetting(
            title: 'New User Alerts',
            subtitle: 'Get notified via email when a new user signs up',
            value: _notifyNewUser,
            onChanged: (value) {
              setState(() => _notifyNewUser = value);
              _saveSetting('notifyNewUser', value);
              _showSaveSnackBar('New User Alerts ${value ? 'Enabled' : 'Disabled'}');
            },
          ),
          _buildDivider(),
          _buildSwitchSetting(
            title: 'Daily Reports',
            subtitle: 'Receive daily statistics report at 9:00 AM',
            value: _dailyReport,
            onChanged: (value) {
              setState(() => _dailyReport = value);
              _saveSetting('dailyReport', value);
              _showSaveSnackBar('Daily Reports ${value ? 'Enabled' : 'Disabled'}');
            },
          ),
          _buildDivider(),
          _buildSwitchSetting(
            title: 'Error Alerts',
            subtitle: 'Immediate notification on system errors',
            value: _errorAlert,
            onChanged: (value) {
              setState(() => _errorAlert = value);
              _saveSetting('errorAlert', value);
              _showSaveSnackBar('Error Alerts ${value ? 'Enabled' : 'Disabled'}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AdminTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textWhite,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AdminTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AdminTheme.primary,
          activeTrackColor: AdminTheme.primary.withOpacity(0.3),
          inactiveThumbColor: AdminTheme.textDisabled,
          inactiveTrackColor: AdminTheme.surfaceHighlight,
        ),
      ],
    );
  }

  /// 데이터 관리
  Widget _buildDataManagement() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButton(
            icon: Icons.backup_outlined,
            title: 'Backup Data',
            subtitle: 'Backup Firestore data to JSON',
            buttonText: 'Start Backup',
            onPressed: () {
              _showConfirmationDialog(
                title: 'Backup Data',
                content: 'Do you want to backup all current data?',
                onConfirm: () {
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) _showSaveSnackBar('Backup completed.');
                  });
                },
              );
            },
          ),
          _buildDivider(),
          _buildActionButton(
            icon: Icons.restore_rounded,
            title: 'Restore Data',
            subtitle: 'Restore data from backup file',
            buttonText: 'Restore',
            onPressed: () {
              // Restore logic
            },
          ),
          _buildDivider(),
          _buildSectionHeader('Data Management'),
          const SizedBox(height: 16),
          _buildSettingsCard(
            child: Column(
              children: [
                _buildSettingsItem(
                  icon: Icons.download_rounded,
                  title: 'Export User Data',
                  subtitle: 'Download all user data as CSV',
                  trailing: FilledButton.icon(
                    onPressed: () async {
                      try {
                        await DataManagementService().exportUsersToCsv();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Export started...'),
                              backgroundColor: AdminTheme.success,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Export failed: $e'),
                              backgroundColor: AdminTheme.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export CSV'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminTheme.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const Divider(color: Colors.white10),
                _buildSettingsItem(
                  icon: Icons.upload_file_rounded,
                  title: 'Import User Data',
                  subtitle: 'Bulk create users from CSV',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showCsvGuide(context),
                        icon: const Icon(Icons.help_outline, size: 18),
                        label: const Text('Guide'),
                        style: TextButton.styleFrom(foregroundColor: AdminTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          final result = await DataManagementService().importUsersFromCsv();
                          if (context.mounted) {
                            _showImportResultDialog(context, result);
                          }
                        },
                        icon: const Icon(Icons.upload, size: 18),
                        label: const Text('Import CSV'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AdminTheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: color ?? AdminTheme.textSecondary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AdminTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textWhite,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AdminTheme.bodyMedium,
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? AdminTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(buttonText),
        ),
      ],
    );
  }

  /// 사용자 관리 정책
  Widget _buildUserPolicies() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolicySetting(
            title: 'Inactive Criteria',
            subtitle: 'Period since last login',
            currentValue: _inactiveCriteria,
            options: ['7 days', '14 days', '30 days', '90 days'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _inactiveCriteria = value);
                _saveSetting('inactiveCriteria', value);
                _showSaveSnackBar('Inactive Criteria Updated');
              }
            },
          ),
          _buildDivider(),
          _buildPolicySetting(
            title: 'Auto-Delete Policy',
            subtitle: 'Criteria for auto-deleting inactive users',
            currentValue: _autoDeletePolicy,
            options: ['Disabled', '180 days', '365 days', '730 days'],
            onChanged: (value) {
              if (value != null) {
                setState(() => _autoDeletePolicy = value);
                _saveSetting('autoDeletePolicy', value);
                _showSaveSnackBar('Auto-Delete Policy Updated');
              }
            },
          ),
          _buildDivider(),
          _buildSwitchSetting(
            title: 'Privacy Masking',
            subtitle: 'Mask sensitive information in lists',
            value: _maskPrivacy,
            onChanged: (value) {
              setState(() => _maskPrivacy = value);
              _saveSetting('maskPrivacy', value);
              _showSaveSnackBar('Privacy Masking ${value ? 'Enabled' : 'Disabled'}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySetting({
    required String title,
    required String subtitle,
    required String currentValue,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AdminTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textWhite,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AdminTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceHighlight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue.replaceAll('일', ' days').replaceAll('비활성화', 'Disabled'), // Simple mapping for demo
              dropdownColor: const Color(0xFF1E1E1E),
              items: options.map((option) {
                return DropdownMenuItem(
                  value: option,
                  child: Text(
                    option,
                    style: AdminTheme.bodyMedium.copyWith(color: AdminTheme.textWhite),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                // Map back to original values if needed, or just use as is
                onChanged(val);
              },
              icon: const Icon(Icons.arrow_drop_down, color: AdminTheme.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 32,
      color: Colors.white.withOpacity(0.05),
    );
  }

  // Helper Methods
  void _showSaveSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AdminTheme.surfaceHighlight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'OK',
          textColor: AdminTheme.primary,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showFeatureNotAvailableDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Notice', style: AdminTheme.titleLarge),
        content: Text('$featureName is not implemented yet.', style: AdminTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AdminTheme.primary),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: AdminTheme.titleLarge),
        content: Text(content, style: AdminTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AdminTheme.textSecondary),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AdminTheme.error : AdminTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
  void _showCsvGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: Text('CSV Import Guide', style: AdminTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CSV 파일은 다음 헤더를 반드시 포함해야 합니다:', style: AdminTheme.bodyMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'UID, Email, Name, Gender, Age, Height, Weight, Activity Level, Role',
                style: GoogleFonts.robotoMono(color: AdminTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            Text('주의: 이미 존재하는 이메일은 건너뜁니다.', style: AdminTheme.bodyMedium.copyWith(color: AdminTheme.warning)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showImportResultDialog(BuildContext context, Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.surface,
        title: Text('Import Result', style: AdminTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildResultRow('Total Rows', '${result['total']}'),
            _buildResultRow('Success', '${result['success']}', color: AdminTheme.success),
            _buildResultRow('Failed', '${result['failed']}', color: AdminTheme.error),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AdminTheme.bodyMedium),
          Text(
            value,
            style: AdminTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color ?? AdminTheme.textWhite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AdminTheme.titleLarge,
    );
  }

  Widget _buildSettingsCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AdminTheme.glassDecoration(
        color: AdminTheme.surface,
        opacity: 0.6,
      ),
      child: child,
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 24, color: AdminTheme.textSecondary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AdminTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AdminTheme.textWhite,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AdminTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
