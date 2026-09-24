import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;

class WebAdminHandoffApp extends StatelessWidget {
  const WebAdminHandoffApp({super.key});

  static const adminUrl = String.fromEnvironment('DFET_ADMIN_WEB_URL');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'D-FET Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF265CC5),
      ),
      home: const _WebAdminHandoffScreen(),
    );
  }
}

class _WebAdminHandoffScreen extends StatelessWidget {
  const _WebAdminHandoffScreen();

  @override
  Widget build(BuildContext context) {
    final configured = WebAdminHandoffApp.adminUrl.isNotEmpty;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, size: 52),
                    const SizedBox(height: 20),
                    Text(
                      'D-FET 관리자 웹 전환',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      configured
                          ? '관리 기능은 Next.js 운영 콘솔로 이전되었습니다.'
                          : '레거시 Flutter 관리자는 종료되었습니다. Next.js 운영 콘솔 배포 주소를 설정해야 합니다.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: configured
                          ? () => html.window.location.assign(
                                WebAdminHandoffApp.adminUrl,
                              )
                          : null,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(configured ? '관리자 웹 열기' : '배포 설정 필요'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
