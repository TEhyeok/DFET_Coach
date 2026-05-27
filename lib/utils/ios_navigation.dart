import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get isCupertinoTarget =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

PageRoute<T> adaptivePageRoute<T>({
  required WidgetBuilder builder,
  bool fullscreenDialog = false,
}) {
  if (isCupertinoTarget) {
    return CupertinoPageRoute<T>(
      builder: builder,
      fullscreenDialog: fullscreenDialog,
    );
  }

  return MaterialPageRoute<T>(
    builder: builder,
    fullscreenDialog: fullscreenDialog,
  );
}
