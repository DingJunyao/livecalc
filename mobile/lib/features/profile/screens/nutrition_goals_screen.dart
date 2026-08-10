import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/repositories/auth_repository.dart';

/// 营养目标：每日热量/蛋白质/碳水/脂肪 4 个数字输入。
/// 热量库存单位 kcal，按 energyUnit 换算显示（对齐 web useUserUnits）。
class NutritionGoalsScreen extends ConsumerStatefulWidget {
  /// 可注入以便测试；生产用默认实现。
  final AuthRepository? authRepository;

  const NutritionGoalsScreen({super.key, this.authRepository});

  @override
  ConsumerState<NutritionGoalsScreen> createState() =>
      _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends ConsumerState<NutritionGoalsScreen> {
  late final TextEditingController _calorie;
  late final TextEditingController _protein;
  late final TextEditingController _carb;
  late final TextEditingController _fat;
  bool _saving = false;

  String get _energyUnit =>
      ref.read(authProvider).user?.unitPreferences?.energyUnit ?? 'kcal';

  /// 库存 kcal → 显示值（kJ ×4.184 取整，对齐 web toDisplayCalorie）。
  double _toDisplay(double? kcal) {
    final v = kcal ?? 0;
    return _energyUnit == 'kJ' ? (v * 4.184).roundToDouble() : v;
  }

  /// 显示值 → 库存 kcal（对齐 web fromDisplayCalorie）。
  double _fromDisplay(double v) =>
      _energyUnit == 'kJ' ? (v / 4.184).roundToDouble() : v;

  @override
  void initState() {
    super.initState();
    final goals = ref.read(authProvider).user?.nutritionGoals ?? const {};
    _calorie = TextEditingController(
        text: _fmt(_toDisplay(goals['daily_calorie_target'] ?? 2000)));
    _protein =
        TextEditingController(text: _fmt(goals['daily_protein_target'] ?? 60));
    _carb =
        TextEditingController(text: _fmt(goals['daily_carb_target'] ?? 300));
    _fat = TextEditingController(text: _fmt(goals['daily_fat_target'] ?? 65));
  }

  @override
  void dispose() {
    _calorie.dispose();
    _protein.dispose();
    _carb.dispose();
    _fat.dispose();
    super.dispose();
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? _parse(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : double.tryParse(t);
  }

  Future<void> _save() async {
    final kcal = _parse(_calorie);
    final protein = _parse(_protein);
    final carb = _parse(_carb);
    final fat = _parse(_fat);
    // 范围校验：kcal 500-5000；kJ 显示 2000-21000（=500/5000 × 4.184 取整）
    if (kcal != null &&
        (kcal < (_energyUnit == 'kJ' ? 2000 : 500) ||
            kcal > (_energyUnit == 'kJ' ? 21000 : 5000))) {
      _toast('每日热量需在 500-5000 千卡范围内');
      return;
    }
    if (protein != null && (protein < 10 || protein > 300)) {
      _toast('蛋白质需在 10-300 克范围内');
      return;
    }
    if (carb != null && (carb < 50 || carb > 600)) {
      _toast('碳水需在 50-600 克范围内');
      return;
    }
    if (fat != null && (fat < 10 || fat > 200)) {
      _toast('脂肪需在 10-200 克范围内');
      return;
    }

    final body = <String, dynamic>{
      // 空输入存 null 清除目标（对齐 web `|| null`），热量先换算回 kcal
      'daily_calorie_target': kcal == null ? null : _fromDisplay(kcal),
      'daily_protein_target': protein,
      'daily_carb_target': carb,
      'daily_fat_target': fat,
    };

    setState(() => _saving = true);
    try {
      final user = await (widget.authRepository ?? AuthRepository())
          .updateMe(body);
      ref.read(authProvider.notifier).applyUser(user);
      if (mounted) {
        _toast('已保存');
        context.pop();
      }
    } on DioException catch (e) {
      if (mounted) _toast(_extractDetail(e));
    } catch (_) {
      if (mounted) _toast('保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _extractDetail(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    return '保存失败，请检查输入后重试';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('营养目标')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '设置每日营养目标，用于饮食推荐。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _calorie,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '每日热量（$_energyUnit）',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _protein,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '蛋白质（g）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _carb,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '碳水（g）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fat,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '脂肪（g）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中...' : '保存'),
          ),
        ],
      ),
    );
  }
}
