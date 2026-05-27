import 'package:flutter/cupertino.dart';
import 'tokens.dart';
import 'ios_text_styles.dart';

/// iOS Cupertino 테마 생성
/// iOS Cupertino 테마 생성
CupertinoThemeData iosThemeDark() {
  return const CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColorsDark.brandPrimary,
    primaryContrastingColor: CupertinoColors.white,
    scaffoldBackgroundColor: AppColors.bgApp,
    barBackgroundColor: AppColors.bgCard,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.textStrong,
      textStyle: IOSTextStyles.body,
      actionTextStyle: IOSTextStyles.button,
      tabLabelTextStyle: IOSTextStyles.tabLabel,
      navTitleTextStyle: IOSTextStyles.headline,
      navLargeTitleTextStyle: IOSTextStyles.largeTitle,
      navActionTextStyle: IOSTextStyles.button,
      pickerTextStyle: IOSTextStyles.body,
      dateTimePickerTextStyle: IOSTextStyles.body,
    ),
  );
}

CupertinoThemeData iosThemeLight() {
  return const CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: AppColorsLight.brandPrimary,
    primaryContrastingColor: CupertinoColors.white,
    scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
    barBackgroundColor: CupertinoColors.systemBackground,
    textTheme: CupertinoTextThemeData(
      primaryColor: CupertinoColors.label,
      textStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.41,
        color: CupertinoColors.label,
      ),
      actionTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.41,
        color: AppColorsLight.brandPrimary,
      ),
      tabLabelTextStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.12,
        color: CupertinoColors.secondaryLabel,
      ),
    ),
  );
}
