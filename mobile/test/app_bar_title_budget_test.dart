import 'dart:io';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/l10n/app_localizations.dart';

/// AppBar 标题预算回归测试。
///
/// 背景：AppBar 标题是单行省略（SDK 强制 softWrap:false + ellipsis），
/// 可用宽度 = 屏宽 − 返回键 − 所有 actions；actions 太多或文案太长时
/// 标题被截成「…」。本测试用真实字体逐屏测量三语标题宽度，
/// 断言在 360dp 最小屏下不超预算。
///
/// 宽度常量来自 Flutter SDK（material/app_bar.dart、text_button.dart）：
/// - 返回键 leadingWidth = kToolbarHeight = 56
/// - IconButton（含 PopupMenuButton）tap target = 48
/// - TextButton：max(64, 水平 padding 24 + labelLarge 14px 文本宽)
///
/// 注意：给某页增删 AppBar actions、或改长标题文案后，需同步更新
/// [_specs] 对应行 —— 表里的按钮数是从源码抄的清单（行内注明源文件）。
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 测试环境默认用 Ahem 字体（所有字形等宽 1em，英文会比真实宽一倍），
  // 这里加载宿主机字体保证测量接近真机：
  // - 中文用 SimHei（覆盖 CJK）
  // - 英文/阿拉伯用 Arial（覆盖拉丁 + 阿拉伯字形）
  // 缺字体时跳过（不阻塞无此字体的机器）。
  Future<bool> loadFont(String family, String path) async {
    final file = File(path);
    if (!file.existsSync()) return false;
    final bytes = file.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    return true;
  }

  const zhFontPath = r'C:\Windows\Fonts\simhei.ttf';
  const latinFontPath = r'C:\Windows\Fonts\arial.ttf';

  final zhOk = await loadFont('AppBarTestZh', zhFontPath);
  final latinOk = await loadFont('AppBarTestLatin', latinFontPath);

  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  double measure(String text, {required bool latin}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 22,
          // AppBar titleLarge：M3 无 letterSpacing、w400。
          fontFamily: latin ? 'AppBarTestLatin' : 'AppBarTestZh',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  double measureButton(String text, {required bool latin}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 14, // labelLarge
          fontFamily: latin ? 'AppBarTestLatin' : 'AppBarTestZh',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return 24 + w; // M3 TextButton 水平 padding 12×2
  }

  /// 屏（AppBar 配置）→ 标题文案清单。
  /// [back] 是否有返回键；[icons] 图标类 action 数；[button] 保存类
  /// TextButton 文案（无则 null）；[dynamicCjk] 动态名标题要求能放下的
  /// 最少汉字数。
  final specs = <_Spec>[
    // ── 根 tab（无返回键）──
    _Spec('home', back: false, icons: 2,
        titles: () => [zh.appBrandShort, en.appBrandShort, ar.appBrandShort]),
    _Spec('price_list', back: false, icons: 2,
        titles: () =>
            [zh.journeyPriceRecords, en.journeyPriceRecords, ar.journeyPriceRecords]),
    _Spec('recipe_list', back: false, icons: 1,
        titles: () => [zh.recipeTitle, en.recipeTitle, ar.recipeTitle]),
    _Spec('profile', back: false, icons: 0,
        titles: () => [zh.profileTitle, en.profileTitle, ar.profileTitle]),
    // ── 列表页（返回键 + 图标）──
    _Spec('ingredient_list', back: true, icons: 1,
        titles: () => [zh.ingredientTitle, en.ingredientTitle, ar.ingredientTitle]),
    _Spec('product_list', back: true, icons: 1,
        titles: () => [zh.productTitle, en.productTitle, ar.productTitle]),
    _Spec('merchant_list', back: true, icons: 2,
        titles: () => [zh.merchantTitle, en.merchantTitle, ar.merchantTitle]),
    _Spec('favorites', back: true, icons: 1,
        titles: () => [zh.navFavorites, en.navFavorites, ar.navFavorites]),
    _Spec('planner_list', back: true, icons: 1,
        titles: () => [zh.navPlans, en.navPlans, ar.navPlans]),
    // 试算新建/编辑（planner_screens.dart）：⋮ + 保存（设为今日只在列表/详情）
    _Spec('planner_form', back: true, icons: 2,
        titles: () => [zh.plansNewPlan, en.plansNewPlan, ar.plansNewPlan,
              zh.plansEdit, en.plansEdit, ar.plansEdit]),
    // ── 详情页：标题是动态实体名，改为断言最少容量（汉字数）──
    // product/ingredient_detail：收藏 + 记价 + ⋮；标题带类型标签
    _Spec('product_detail', back: true, icons: 3, dynamicCjk: 5,
        chip: () => [zh.productChip, en.productChip, ar.productChip]),
    _Spec('ingredient_detail', back: true, icons: 3, dynamicCjk: 5,
        chip: () => [zh.ingredientChip, en.ingredientChip, ar.ingredientChip]),
    _Spec('merchant_detail', back: true, icons: 1, dynamicCjk: 8),
    _Spec('plan_detail', back: true, icons: 2, dynamicCjk: 8),
    _Spec('recipe_detail', back: true, icons: 3, dynamicCjk: 7),
    // recipe_analysis：无 icon，标题 = 名称 + 「分析」chip
    _Spec('recipe_analysis', back: true, icons: 0, dynamicCjk: 10,
        chip: () => [zh.recipeAnalysisChip, en.recipeAnalysisChip, ar.recipeAnalysisChip]),
    // ── 表单页（返回键 + 保存 TextButton）──
    _Spec('price_record_form', back: true, icons: 0, button: () => zh.commonSave,
        titles: () =>
            [zh.priceAddRecordTitle, en.priceAddRecordTitle, ar.priceAddRecordTitle]),
    _Spec('price_record_edit', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [
              zh.priceEditTitle, en.priceEditTitle, ar.priceEditTitle,
              zh.priceRecordTitle, en.priceRecordTitle, ar.priceRecordTitle,
            ]),
    _Spec('ingredient_form', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [
              zh.ingredientEditTitle, en.ingredientEditTitle, ar.ingredientEditTitle,
              zh.ingredientAddTitle, en.ingredientAddTitle, ar.ingredientAddTitle,
            ]),
    _Spec('product_form', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [
              zh.productEditTitle, en.productEditTitle, ar.productEditTitle,
              zh.productAddTitle, en.productAddTitle, ar.productAddTitle,
            ]),
    _Spec('merchant_form', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [
              zh.merchantEditTitle, en.merchantEditTitle, ar.merchantEditTitle,
              zh.merchantAddTitle, en.merchantAddTitle, ar.merchantAddTitle,
            ]),
    _Spec('recipe_form', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [
              zh.recipeCreateTitle, en.recipeCreateTitle, ar.recipeCreateTitle,
              zh.recipeEditTitle, en.recipeEditTitle, ar.recipeEditTitle,
              zh.recipeEditBasicInfo, en.recipeEditBasicInfo, ar.recipeEditBasicInfo,
              zh.recipeEditIngredients, en.recipeEditIngredients, ar.recipeEditIngredients,
              zh.recipeEditSteps, en.recipeEditSteps, ar.recipeEditSteps,
              zh.recipeEditTips, en.recipeEditTips, ar.recipeEditTips,
            ]),
    _Spec('user_place_form', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [zh.userPlaceEditTitle, en.userPlaceEditTitle, ar.userPlaceEditTitle,
              zh.placeAdd, en.placeAdd, ar.placeAdd]),
    _Spec('edit_account', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [zh.authEditAccountTitle, en.authEditAccountTitle, ar.authEditAccountTitle]),
    _Spec('nutrition_goals', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [zh.profileNutritionGoals, en.profileNutritionGoals, ar.profileNutritionGoals]),
    _Spec('unit_preferences', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [zh.profileUnitPreferences, en.profileUnitPreferences, ar.profileUnitPreferences]),
    // 单位编辑 / 密度编辑 / 数量关联编辑（entity_units_card、entity_quantity_link_edit_page）
    _Spec('entity_units_editor', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [zh.unitsEditTitle, en.unitsEditTitle, ar.unitsEditTitle,
              zh.unitsAddTitle, en.unitsAddTitle, ar.unitsAddTitle,
              zh.densityAddTitle, en.densityAddTitle, ar.densityAddTitle]),
    _Spec('entity_link_editor', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [zh.entityLinksEdit, en.entityLinksEdit, ar.entityLinksEdit,
              zh.entityLinksAddTitle, en.entityLinksAddTitle, ar.entityLinksAddTitle]),
    _Spec('entity_units_draft', back: true, icons: 1,
        titles: () => [zh.unitsCustomTab, en.unitsCustomTab, ar.unitsCustomTab]),
    // ── 其他 ──
    // ingredient_hierarchy：返回键 + 「完成」TextButton + 底部 TabBar
    _Spec('ingredient_hierarchy', back: true, icons: 0, button: () => zh.commonDone,
        titles: () => [zh.ingredientManageRelations, en.ingredientManageRelations, ar.ingredientManageRelations]),
    // nutrition_edit：返回键 + 保存 TextButton（「清空自定义」已移入 body）
    _Spec('nutrition_edit', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [zh.nutritionEditTitle, en.nutritionEditTitle, ar.nutritionEditTitle]),
    _Spec('register', back: true, icons: 0,
        titles: () => [zh.authRegisterTitle, en.authRegisterTitle, ar.authRegisterTitle]),
    _Spec('my_proposals', back: true, icons: 0,
        titles: () => [zh.profileMyProposals, en.profileMyProposals, ar.profileMyProposals]),
    _Spec('my_places', back: true, icons: 0,
        titles: () => [zh.profileMyPlaces, en.profileMyPlaces, ar.profileMyPlaces]),
    // 自定义计算范围：列表（返回键，FAB 在 body）+ 表单（返回键 + 保存 TextButton）
    _Spec('calc_scope_list', back: true, icons: 0,
        titles: () => [zh.calcScopeListTitle, en.calcScopeListTitle, ar.calcScopeListTitle]),
    _Spec('calc_scope_form', back: true, icons: 0, button: () => zh.commonSave,
        titles: () => [zh.calcScopeEdit, en.calcScopeEdit, ar.calcScopeEdit,
              zh.calcScopeAdd, en.calcScopeAdd, ar.calcScopeAdd]),
    _Spec('blacklist', back: true, icons: 0,
        titles: () => [zh.blacklistTitle, en.blacklistTitle, ar.blacklistTitle]),
    _Spec('paste_import', back: true, icons: 0,
        titles: () => [zh.pricePasteImportTitle, en.pricePasteImportTitle, ar.pricePasteImportTitle]),
    // quick_fill：返回键 + 粘贴 + 保存 两个图标
    _Spec('quick_fill', back: true, icons: 2,
        titles: () => [zh.quickFillTitle, en.quickFillTitle, ar.quickFillTitle]),
  ];

  test('宿主机测试字体可用（缺失则本文件其余用例跳过）', () {
    expect(zhOk && latinOk, isTrue,
        reason: '缺少 $zhFontPath 或 $latinFontPath，标题宽度测量无法进行');
  });

  for (final spec in specs) {
    testWidgets('AppBar 标题预算：${spec.name}', (tester) async {
      if (!zhOk || !latinOk) {
        markTestSkipped('宿主机缺测试字体，跳过标题预算测量');
        return;
      }
      var budget = 360.0;
      if (spec.back) budget -= 56;
      budget -= 48.0 * spec.icons;
      if (spec.button != null) {
        budget -= measureButton(spec.button!(), latin: false);
      }

      if (spec.dynamicCjk != null) {
        // 动态实体名标题：断言至少能放下 N 个汉字
        expect(
          budget,
          greaterThanOrEqualTo(spec.dynamicCjk! * 22.0),
          reason: '${spec.name} 动态标题预算不足 '
              '${spec.dynamicCjk} 个汉字（实际 ${budget.toStringAsFixed(0)}px）',
        );
        // chip 页额外断言：扣除 chip 后按该语言字宽仍有容量
        //（汉字 22px/字，拉丁/阿拉伯 ≈11.5px/字）。
        if (spec.chip != null) {
          for (final chipText in spec.chip!()) {
            final isLatin =
                !chipText.codeUnits.any((c) => c >= 0x2E80 && c <= 0x9FFF);
            final chipWidth = measureChip(chipText, latin: isLatin);
            final unit = isLatin ? 11.5 : 22.0;
            expect(budget - chipWidth - 8,
                greaterThanOrEqualTo(spec.dynamicCjk! * unit),
                reason: '${spec.name} 扣除 chip「$chipText」后动态标题容量不足 '
                    '${spec.dynamicCjk} 字（实际 '
                    '${(budget - chipWidth - 8).toStringAsFixed(0)}px）');
          }
        }
        return;
      }

      for (final title in spec.titles!()) {
        final isLatin = !title.codeUnits.any((c) => c >= 0x2E80 && c <= 0x9FFF);
        final w = measure(title, latin: isLatin);
        expect(w, lessThanOrEqualTo(budget),
            reason: '${spec.name} 标题「$title」宽 ${w.toStringAsFixed(0)}px '
                '超过预算 ${budget.toStringAsFixed(0)}px（360dp 屏），会被截断');
      }
    });
  }
}

/// chip 用 labelSmall（11px）+ 水平 padding 8×2 测量。
double measureChip(String text, {required bool latin}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
          fontSize: 11,
          fontFamily: latin ? 'AppBarTestLatin' : 'AppBarTestZh'),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final w = tp.width;
  tp.dispose();
  return w + 16;
}

class _Spec {
  _Spec(
    this.name, {
    required this.back,
    required this.icons,
    this.button,
    this.titles,
    this.dynamicCjk,
    this.chip,
  });

  final String name;
  final bool back;
  final int icons;
  final String Function()? button;
  final List<String> Function()? titles;
  final int? dynamicCjk;
  final List<String> Function()? chip;
}
