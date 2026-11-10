import 'package:flutter/material.dart';

/// Màu chủ đạo: đỏ son và vàng đồng – gợi không khí nhà thờ họ.
class AppColors {
  AppColors._();

  static const seed = Color(0xFF9B1C1C);
  static const gold = Color(0xFFB8860B);
  static const male = Color(0xFF1D4E89);
  static const female = Color(0xFFA23B72);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}

/// Màu nhận diện giới tính (luôn đi kèm biểu tượng, không dùng màu đơn lẻ).
Color genderColor(BuildContext context, bool isMale) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (isMale) return dark ? const Color(0xFF8DB8F0) : AppColors.male;
  return dark ? const Color(0xFFF0A0C8) : AppColors.female;
}
