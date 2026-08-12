import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/core/theme/app_theme.dart';

void main() {
  // 此组非"常量等于自身"的同义反复：它是回归护栏。锁定各档位的目标
  // 数值，令对单个常量的粗心改动被立即捕获——刻度即契约。
  group('AppFontSizes 刻度', () {
    test('提供全 app 唯一字号常量', () {
      expect(AppFontSizes.display, 36);
      expect(AppFontSizes.headline, 28);
      expect(AppFontSizes.headlineSmall, 24);
      expect(AppFontSizes.title, 16);
      expect(AppFontSizes.body, 16);
      expect(AppFontSizes.bodySecondary, 14);
      expect(AppFontSizes.caption, 12);
      expect(AppFontSizes.label, 14);
      expect(AppFontSizes.labelMedium, 12);
      expect(AppFontSizes.micro, 11);
    });
  });

  group('lightTheme textTheme 锁死字号', () {
    final theme = AppTheme.lightTheme;

    test('headlineMedium 锁死为 28', () {
      expect(theme.textTheme.headlineMedium!.fontSize, 28);
    });
    test('headlineSmall 锁死为 24', () {
      expect(theme.textTheme.headlineSmall!.fontSize, 24);
    });
    test('titleMedium 锁死为 16', () {
      expect(theme.textTheme.titleMedium!.fontSize, 16);
    });
    test('bodyLarge 锁死为 16', () {
      expect(theme.textTheme.bodyLarge!.fontSize, 16);
    });
    test('bodyMedium 锁死为 14', () {
      expect(theme.textTheme.bodyMedium!.fontSize, 14);
    });
    test('bodySmall 锁死为 12', () {
      expect(theme.textTheme.bodySmall!.fontSize, 12);
    });
    test('labelLarge 锁死为 14', () {
      expect(theme.textTheme.labelLarge!.fontSize, 14);
    });
    test('labelMedium 锁死为 12', () {
      expect(theme.textTheme.labelMedium!.fontSize, 12);
    });
    test('labelSmall 锁死为 11', () {
      expect(theme.textTheme.labelSmall!.fontSize, 11);
    });

    test('primaryTextTheme 也锁死 bodyLarge', () {
      expect(theme.primaryTextTheme.bodyLarge!.fontSize, 16);
    });
  });

  group('darkTheme textTheme 同样锁死', () {
    final theme = AppTheme.darkTheme;

    test('bodyLarge / labelSmall 在暗色模式也锁死', () {
      expect(theme.textTheme.bodyLarge!.fontSize, 16);
      expect(theme.textTheme.labelSmall!.fontSize, 11);
    });
  });
}
