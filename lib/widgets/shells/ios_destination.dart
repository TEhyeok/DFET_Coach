import 'package:flutter/cupertino.dart';

enum IOSDestination {
  home,
  record,
  coaching,
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
      case IOSDestination.coaching:
        return CupertinoIcons.chart_bar_square_fill;
      case IOSDestination.community:
        return CupertinoIcons.person_2_fill;
      case IOSDestination.profile:
        return CupertinoIcons.person_crop_circle_fill;
    }
  }
}
