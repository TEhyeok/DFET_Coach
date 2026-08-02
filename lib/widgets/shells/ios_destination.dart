import 'package:flutter/cupertino.dart';

enum IOSDestination {
  home,
  record,
  report, // 2026 개편: 통합 리포트 (코칭 통계 + 장 건강, careType별 분기)
  microbiome, // 장 건강 (리포트 내부에서 사용)
  coaching, // 코칭 통계 (리포트 내부에서 사용)
  community,
  profile,
}

extension IOSDestinationMeta on IOSDestination {
  String get title {
    switch (this) {
      case IOSDestination.home:
        return 'D-FET';
      case IOSDestination.record:
        return '기록';
      case IOSDestination.report:
        return '리포트';
      case IOSDestination.microbiome:
        return '장 건강';
      case IOSDestination.coaching:
        return '코칭';
      case IOSDestination.community:
        return '커뮤니티';
      case IOSDestination.profile:
        return '내 정보';
    }
  }

  String get label {
    switch (this) {
      case IOSDestination.home:
        return '홈';
      case IOSDestination.record:
        return '기록';
      case IOSDestination.report:
        return '리포트';
      case IOSDestination.microbiome:
        return '장 건강';
      case IOSDestination.coaching:
        return '코칭';
      case IOSDestination.community:
        return '커뮤니티';
      case IOSDestination.profile:
        return '내 정보';
    }
  }

  IconData get icon {
    switch (this) {
      case IOSDestination.home:
        return CupertinoIcons.house;
      case IOSDestination.record:
        return CupertinoIcons.square_pencil;
      case IOSDestination.report:
        return CupertinoIcons.chart_bar_square;
      case IOSDestination.microbiome:
        return CupertinoIcons.lab_flask;
      case IOSDestination.coaching:
        return CupertinoIcons.chart_bar_square;
      case IOSDestination.community:
        return CupertinoIcons.person_2;
      case IOSDestination.profile:
        return CupertinoIcons.person_crop_circle;
    }
  }

  IconData get activeIcon {
    switch (this) {
      case IOSDestination.home:
        return CupertinoIcons.house_fill;
      case IOSDestination.record:
        return CupertinoIcons.square_pencil_fill;
      case IOSDestination.report:
        return CupertinoIcons.chart_bar_square_fill;
      case IOSDestination.microbiome:
        return CupertinoIcons.lab_flask_solid;
      case IOSDestination.coaching:
        return CupertinoIcons.chart_bar_square_fill;
      case IOSDestination.community:
        return CupertinoIcons.person_2_fill;
      case IOSDestination.profile:
        return CupertinoIcons.person_crop_circle_fill;
    }
  }
}
