import 'package:flutter/material.dart';
import 'tokens.dart';

class AppTextStyles {
  // Headings
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: AppColors.textStrong,
  );

  static const h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textStrong,
  );

  static const h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textStrong,
  );

  // Body
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textBody,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textBody,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSubtle,
  );

  // Special
  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSubtle,
  );

  static const number = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: AppColors.textStrong,
  );

  static const kpi = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.3,
    color: AppColors.textStrong,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSubtle,
    letterSpacing: 0.5,
  );
}
