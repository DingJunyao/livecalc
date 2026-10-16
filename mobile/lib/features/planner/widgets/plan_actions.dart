import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../repositories/planner_repository.dart';

/// 「设为今日」：「一顿」方案先选要替换哪一餐，「一日」方案一次设三餐（与 web 同口径）。
/// 返回是否真的设过（取消或失败时返回 false，失败已弹提示）。
Future<bool> setPlanToday(
    BuildContext context, Map<String, dynamic> plan) async {
  final l10n = AppLocalizations.of(context);
  String? mealType;
  if (plan['kind'] != 'day') {
    mealType = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.plansSetToday),
        children: [
          for (final entry in {
            'breakfast': l10n.homeBreakfast,
            'lunch': l10n.homeLunch,
            'dinner': l10n.homeDinner,
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (mealType == null) return false;
  }
  try {
    await PlannerRepository().setPlan(plan['id'] as int, mealType: mealType);
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.plansSetTodayDone)),
    );
    return true;
  } on Exception {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.plansSetTodayFailed)),
    );
    return false;
  }
}

/// 删除确认：返回 true 表示用户确认删除。
Future<bool> confirmDeletePlan(
    BuildContext context, Map<String, dynamic> plan) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.plansDeleteTitle),
      content: Text('${plan['name']}?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.commonConfirm),
        ),
      ],
    ),
  );
  return confirmed == true;
}
