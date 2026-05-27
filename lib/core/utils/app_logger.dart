import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// 앱 전역 로거
/// 프로덕션에서는 print() 대신 이 로거를 사용하여
/// 로그 레벨을 제어하고 민감한 정보 노출을 방지합니다.
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kReleaseMode ? Level.warning : Level.debug,
  );

  /// 디버그 로그 (개발 중에만 표시)
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// 정보 로그
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// 경고 로그
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// 에러 로그
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// 치명적 에러 로그
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}
