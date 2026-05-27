import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';

import '../../models/user_profile.dart';
import '../../theme/admin_theme.dart';

/// 사용자 목록 Provider
final usersListProvider = FutureProvider<List<UserProfile>>((ref) async {
  final adminService = AdminService();
  return await adminService.getAllUsers();
});

/// 검색 쿼리 Provider
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 사용자 목록 페이지
class UsersListPage extends ConsumerStatefulWidget {
  const UsersListPage({super.key});

  @override
  ConsumerState<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends ConsumerState<UsersListPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String? _hoveredUserId; // 호버된 사용자 UID

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Debounce 검색 입력 (500ms)
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Users Management', style: AdminTheme.displaySmall),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 검색 바
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AdminTheme.glassDecoration(
              color: AdminTheme.surface,
              opacity: 0.6,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: AdminTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Search by email or name...',
                      hintStyle: AdminTheme.bodyMedium.copyWith(color: AdminTheme.textDisabled),
                      prefixIcon: const Icon(Icons.search, color: AdminTheme.textSecondary),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AdminTheme.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(searchQueryProvider.notifier).state = '';
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AdminTheme.primary),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.refresh(usersListProvider);
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 사용자 목록
          Expanded(
            child: usersAsync.when(
              data: (users) {
                final filteredUsers = _filterUsers(users, searchQuery);
                return _buildUsersList(filteredUsers);
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AdminTheme.primary)),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AdminTheme.error),
                    const SizedBox(height: 16),
                    Text('Failed to load data: $error', style: AdminTheme.bodyLarge),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(usersListProvider),
                      style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primary),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<UserProfile> _filterUsers(List<UserProfile> users, String query) {
    if (query.isEmpty) return users;

    final lowerQuery = query.toLowerCase();
    return users.where((user) {
      final email = user.email?.toLowerCase() ?? '';
      final name = user.displayName?.toLowerCase() ?? '';
      return email.contains(lowerQuery) || name.contains(lowerQuery);
    }).toList();
  }

  Widget _buildUsersList(List<UserProfile> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: AdminTheme.textDisabled),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: AdminTheme.titleMedium.copyWith(color: AdminTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        decoration: AdminTheme.glassDecoration(
          color: AdminTheme.surface,
          opacity: 0.6,
        ),
        child: Column(
          children: [
            // 헤더
            _buildTableHeader(),
            Divider(height: 1, color: Colors.white.withOpacity(0.1)),

            // 사용자 목록
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Column(
                  children: [
                    if (index > 0) Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                    _buildUserRow(user),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 48), // 아바타 공간
          Expanded(
            flex: 2,
            child: Text(
              'Email',
              style: AdminTheme.titleMedium.copyWith(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              'Name',
              style: AdminTheme.titleMedium.copyWith(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              'Joined',
              style: AdminTheme.titleMedium.copyWith(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              'Last Login',
              style: AdminTheme.titleMedium.copyWith(fontSize: 13),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              'Action',
              style: AdminTheme.titleMedium.copyWith(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(UserProfile user) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final isActive =
        user.lastLoginAt != null && user.lastLoginAt!.isAfter(sevenDaysAgo);
    final isHovered = _hoveredUserId == user.uid;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredUserId = user.uid),
      onExit: (_) => setState(() => _hoveredUserId = null),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () {
          context.go('/admin/users/${user.uid}', extra: {'userName': user.displayName});
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          color: isHovered ? Colors.white.withOpacity(0.05) : Colors.transparent,
          child: Row(
            children: [
              // 아바타
              CircleAvatar(
                radius: 20,
                backgroundColor: isActive ? AdminTheme.success : AdminTheme.textDisabled.withOpacity(0.3),
                child: Text(
                  (user.displayName?.isNotEmpty ?? false)
                      ? user.displayName![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 이메일
              Expanded(
                flex: 2,
                child: Text(
                  user.email ?? '-',
                  style: AdminTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 이름
              Expanded(
                child: Text(
                  user.displayName ?? '-',
                  style: AdminTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 가입일
              Expanded(
                child: Text(
                  user.createdAt != null
                      ? DateFormat('yyyy-MM-dd').format(user.createdAt!)
                      : '-',
                  style: AdminTheme.bodyMedium,
                ),
              ),

              // 마지막 로그인
              Expanded(
                child: Row(
                  children: [
                    if (isActive)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: AdminTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        user.lastLoginAt != null
                            ? DateFormat('yyyy-MM-dd').format(user.lastLoginAt!)
                            : '-',
                        style: AdminTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // 상태 표시
              SizedBox(
                width: 100,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AdminTheme.primary.withOpacity(0.5)),
                    ),
                    child: Text(
                      'Details',
                      style: AdminTheme.bodyMedium.copyWith(
                        fontSize: 12,
                        color: AdminTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

