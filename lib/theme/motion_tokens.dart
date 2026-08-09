import 'package:flutter/animation.dart';

/// D-FET 화면 전반에서 공유하는 짧고 절제된 모션 규칙.
abstract final class DfetMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 280);
  static const pageEnter = Duration(milliseconds: 760);
  static const pulse = Duration(milliseconds: 1400);

  static const Curve emphasized = Curves.easeOutCubic;
}
