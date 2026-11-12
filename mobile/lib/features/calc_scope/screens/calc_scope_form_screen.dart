import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_exit_guard.dart';
import '../../../shared/widgets/save_action_button.dart';
import '../models/calc_scope.dart';
import '../providers/calc_scope_provider.dart';
import '../widgets/region_multi_select_field.dart';
import '../../merchants/repositories/merchant_repository.dart';
import 'calc_scope_list_screen.dart'
    show calcScopeWriteError; // 复用同一错误文案提取
import '../../profile/providers/save_button_position_provider.dart';

class CalcScopeFormResult {
  final bool saved;

  const CalcScopeFormResult({required this.saved});
}

class CalcScopeFormArguments {
  final CalcScope? scope;

  const CalcScopeFormArguments({this.scope});
}

/// 新建/编辑自定义计算范围：名称 + 多地区选择（层级可混合）。
class CalcScopeFormScreen extends ConsumerStatefulWidget {
  final CalcScope? scope;

  /// 地区数据仓库（测试注入内存实现，默认走 /regions 接口）。
  final MerchantRepository? regionRepository;

  const CalcScopeFormScreen({super.key, this.scope, this.regionRepository});

  @override
  ConsumerState<CalcScopeFormScreen> createState() =>
      _CalcScopeFormScreenState();
}

class _CalcScopeFormScreenState extends ConsumerState<CalcScopeFormScreen> {
  late final TextEditingController _nameController;
  late List<int> _regionIds;
  late final List<int> _initialRegionIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.scope?.name ?? '');
    _regionIds = [...(widget.scope?.regionIds ?? const <int>[])];
    _initialRegionIds = List.of(_regionIds);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasUnsavedInput =>
      widget.scope == null &&
      (_nameController.text.trim().isNotEmpty ||
          !_listEquals(_regionIds, _initialRegionIds));

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.calcScopeNameRequired)),
      );
      return;
    }
    if (_regionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.calcScopeRegionRequired)),
      );
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': name,
      'region_ids': _regionIds,
    };
    try {
      final notifier = ref.read(calcScopeListProvider.notifier);
      final scope = widget.scope;
      if (scope == null) {
        await notifier.add(body);
      } else {
        await notifier.update(scope.id, body);
      }
      if (!mounted) return;
      context.pop(const CalcScopeFormResult(saved: true));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(calcScopeWriteError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.scope != null;
    final savePosition = ref.watch(saveButtonPositionProvider);
    final saveLabel = editing ? l10n.commonSave : l10n.commonAdd;
    return FormExitGuard(
      enabled: !editing && !_saving,
      isDirty: () => _hasUnsavedInput,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              editing ? l10n.calcScopeEdit : l10n.calcScopeAdd),
          actions: [
            ...saveAppBarActions(
              position: savePosition,
              onSave: _saving ? null : _save,
              label: _saving ? l10n.commonSaving : saveLabel,
            ),
          ],
        ),
        bottomNavigationBar: saveBottomBar(
          context: context,
          position: savePosition,
          onSave: _saving ? null : _save,
          label: _saving ? l10n.commonSaving : saveLabel,
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: l10n.calcScopeNameLabel,
                    hintText: l10n.calcScopeNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.calcScopeRegionsLabel,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                RegionMultiSelectField(
                  value: _regionIds,
                  onChanged: (ids) => setState(() => _regionIds = ids),
                  repository: widget.regionRepository,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
