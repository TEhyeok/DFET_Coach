import 'package:flutter/material.dart';
import '../../theme/admin_theme.dart';
import 'admin_sidebar.dart';
import 'admin_header.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;
  final String currentPage;

  const AdminLayout({
    super.key,
    required this.child,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Background Mesh Gradients (Aurora Effect)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AdminTheme.primary.withOpacity(isLight ? 0.1 : 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AdminTheme.secondary.withOpacity(isLight ? 0.1 : 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

            // 2. Main Layout
            Row(
              children: [
                // Sidebar
                AdminSidebar(currentPage: currentPage),

                // Content Area
                Expanded(
                  child: SelectionArea(
                    child: Column(
                      children: [
                        const AdminHeader(),
                        Expanded(
                          child: ClipRect(
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}
