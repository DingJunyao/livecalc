import 'package:flutter/material.dart';

/// 全 app 唯一字号刻度常量。新增字号一律从此取，禁止散落 magic number。
///
/// `display` (36) 暂无 textTheme 锁定档位，留作未来 hero 文案——
/// 届时通过 [display] 直接取值显式应用，而非走 M3 默认。
abstract final class AppFontSizes {
  static const double display = 36;
  static const double headline = 28;
  static const double headlineSmall = 24;
  static const double title = 16;
  static const double body = 16;
  static const double bodySecondary = 14;
  static const double caption = 12;
  static const double label = 14;
  static const double labelMedium = 12;
  static const double micro = 11;
}

class AppTheme {
  static const Color _primaryColor = Color(0xFF558B2F);
  static const Color _secondaryColor = Color(0xFF547C8C);
 static const Color _errorColor = Color(0xFFBA1A1A);

  /// 中文字体回退链：按平台优先级，确保 CJK 字形使用设备原生高质量字体，
  /// 而非 Flutter 默认 Roboto 的位图兜底。Latin 仍用默认 Roboto。
  static const _cjkFontFallback = [
    'Noto Sans CJK SC',   // Android / Linux
    'Source Han Sans SC', // 别名
    'Source Han Sans CN',
    'PingFang SC',        // iOS / macOS
    'Microsoft YaHei',    // Windows
    '微软雅黑',
    'sans-serif',
  ];

 static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      secondary: _secondaryColor,
      error: _errorColor,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      secondary: _secondaryColor,
      error: _errorColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

 static ThemeData _buildTheme(ColorScheme colorScheme) {
   final base = ThemeData(
     useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
       border: OutlineInputBorder(
         borderRadius: BorderRadius.circular(12),
       ),
     ),
   );
   // 全局应用中文字体回退，保证中文渲染清晰、行高一致
   return base.copyWith(
     textTheme: _withLockedFontSizes(
         base.textTheme.apply(fontFamilyFallback: _cjkFontFallback)),
     primaryTextTheme: _withLockedFontSizes(
         base.primaryTextTheme.apply(fontFamilyFallback: _cjkFontFallback)),
   );
 }

  /// 将 textTheme 各档位字号锁死到 [AppFontSizes] 刻度，
  /// 使全 app 字号唯一可调、免受 Material 默认值漂移影响。
  static TextTheme _withLockedFontSizes(TextTheme t) {
    return t.copyWith(
      headlineMedium:
          t.headlineMedium?.copyWith(fontSize: AppFontSizes.headline),
      headlineSmall:
          t.headlineSmall?.copyWith(fontSize: AppFontSizes.headlineSmall),
      titleMedium: t.titleMedium?.copyWith(fontSize: AppFontSizes.title),
      bodyLarge: t.bodyLarge?.copyWith(fontSize: AppFontSizes.body),
      bodyMedium: t.bodyMedium?.copyWith(fontSize: AppFontSizes.bodySecondary),
      bodySmall: t.bodySmall?.copyWith(fontSize: AppFontSizes.caption),
      labelLarge: t.labelLarge?.copyWith(fontSize: AppFontSizes.label),
      labelMedium: t.labelMedium?.copyWith(fontSize: AppFontSizes.labelMedium),
      labelSmall: t.labelSmall?.copyWith(fontSize: AppFontSizes.micro),
    );
  }
}
