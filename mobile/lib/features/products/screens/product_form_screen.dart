import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/models/entity_unit.dart';
import '../../../shared/models/nutrition.dart';
import '../../../shared/screens/entity_units_draft_screen.dart';
import '../../../shared/screens/nutrition_edit_screen.dart';
import '../../../shared/services/entity_draft_persist.dart';
import '../../../shared/utils/draft_units.dart';
import '../../../shared/widgets/alias_tags_field.dart';
import '../../entities/repositories/entity_repository.dart';
import '../../ingredients/models/ingredient.dart';
import '../../ingredients/repositories/ingredient_repository.dart';
import '../../prices/providers/price_provider.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';
import '../../../shared/widgets/barcode_scanner_sheet.dart';
import '../../../shared/widgets/loading_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/save_action_button.dart';
import '../../profile/providers/save_button_position_provider.dart';

class ProductFormPrefill {
  final String barcode;
  final String name;
  final String brand;

  const ProductFormPrefill({
    this.barcode = '',
    this.name = '',
    this.brand = '',
  });
}

class ProductFormResult {
  final bool saved;
  final bool pending;
  final String message;
  final Product? product;

  const ProductFormResult({
    required this.saved,
    required this.pending,
    required this.message,
    this.product,
  });
}

class ProductFormScreen extends ConsumerStatefulWidget {
  final Ingredient? fixedIngredient;
  final Product? product;
  final ProductRepository? repository;
  final IngredientRepository? ingredientRepository;
  /// 测试注入：单位/密度参照数据来源（缺省走真实接口）。
  final EntityRepository? entityRepository;
  /// 测试注入：草稿落库器（缺省按 isAdmin 现场构造）。
  final EntityDraftPersister? draftPersister;
  final bool isAdmin;
  final ProductFormPrefill? prefill;
  final Future<String?> Function(BuildContext context)? scanner;

  const ProductFormScreen({
    super.key,
    this.fixedIngredient,
    this.product,
    this.repository,
    this.ingredientRepository,
    this.entityRepository,
    this.draftPersister,
    this.isAdmin = false,
    this.prefill,
    this.scanner,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  late final ProductRepository _productRepository;
  late final IngredientRepository _ingredientRepository;
  late final EntityRepository _entityRepository;
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _ingredientSearchController;
  final FocusNode _ingredientFocusNode = FocusNode();
  Timer? _ingredientSearchDebounce;
  Completer<List<Ingredient>>? _ingredientSearchCompleter;
  int _ingredientSearchSeq = 0;
  String? _ingredientSearchQuery;
  List<String> _aliases = const [];
  List<String> _tags = const [];
  Ingredient? _selectedIngredient;
  bool _createNewIngredient = false;
  bool _barcodeLoading = false;
  bool _searching = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  // 我的权重覆盖（仅编辑态显示；个人偏好不走审核）
  bool _myWeightEnabled = false;
  int _myWeight = 50;
  int _globalWeight = 50;
  /// 表单载入时的商品名（用于判断保存时是否真的改名 → 决定要不要刷新价格列表）
  String _initialName = '';
  /// 表单载入时的关联原料 id：保存时对比判断是否换绑原料（触发引用调和）
  int? _initialIngredientId;
  /// 最近一次**选中**的关联原料 id：草稿单位里的引用指向它。
  ///
  /// 不能直接用 `_selectedIngredient?.id`：在搜索框里打字时 `onChanged` 会先把选中
  /// 清空（用户往往只是想重打），等 `onSelected` 触发时已经读不到「原来引用的是哪个
  /// 原料的单位」，于是无从按名字改指向、只能误删。
  int? _lastSelectedIngredientId;

  // 新增商品时先填好的「自定义单位 / 营养信息」草稿：商品创建成功后才落库
  final List<EntityUnit> _draftUnits = [];
  List<NutrientEntry> _draftNutrients = const [];
  // 单位草稿的参照数据（全局单位、关联原料的单位与密度），进入草稿页前懒加载
  List<GlobalUnitOption> _globalUnitOptions = const [];
  List<EntityUnit> _inheritedUnits = const [];
  double _draftDensityKgM3 = 1000;
  bool _loadingDraftUnits = false;
  bool _draftUnitsLoaded = false;
  int? _draftReferenceIngredientId;

  bool get _isEdit => widget.product != null;

  int get _draftNutrientCount => _draftNutrients
      .where((entry) => entry.label.trim().isNotEmpty && entry.value > 0)
      .length;

  @override
  void initState() {
    super.initState();
    _productRepository = widget.repository ?? ProductRepository();
    _ingredientRepository =
        widget.ingredientRepository ?? IngredientRepository();
    _entityRepository = widget.entityRepository ?? EntityRepository();
    final initialProduct = widget.product?.mergedWithPending();
    _nameController = TextEditingController(
      text: widget.prefill?.name ?? initialProduct?.name,
    );
    _brandController = TextEditingController(
      text: widget.prefill?.brand ?? initialProduct?.brand,
    );
    _barcodeController = TextEditingController(
      text: widget.prefill?.barcode ?? initialProduct?.barcode,
    );
    _ingredientSearchController = TextEditingController();
    _selectedIngredient = widget.fixedIngredient;
    _initialName = _nameController.text.trim();
    _initialIngredientId = initialProduct?.ingredientId ?? widget.fixedIngredient?.id;
    _lastSelectedIngredientId = _initialIngredientId;

    if (_isEdit) {
      _loading = true;
      Future.microtask(_loadProduct);
    }
  }

  @override
  void dispose() {
    _cancelPendingIngredientSearch();
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _ingredientSearchController.dispose();
    _ingredientFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    final l10n = AppLocalizations.of(context);
    try {
      final product = (await _productRepository.getProduct(widget.product!.id))
          .mergedWithPending();
      // 我的权重覆盖与商品信息并行加载；失败不阻塞表单（与 web 行为一致）
      MyWeightInfo? myWeight;
      try {
        myWeight = await _productRepository.getMyWeight(widget.product!.id);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _nameController.text = product.name;
        _initialName = product.name.trim();
        _brandController.text = product.brand ?? '';
        _barcodeController.text = product.barcode ?? '';
        _aliases = List.of(product.aliases);
        _tags = List.of(product.tags);
        _selectedIngredient = product.ingredientId == null
            ? null
            : Ingredient(
                id: product.ingredientId!,
                name: product.ingredientName ?? '',
              );
        _ingredientSearchController.text = _selectedIngredient?.name ?? '';
        _initialIngredientId = product.ingredientId;
        _lastSelectedIngredientId = product.ingredientId;
        if (myWeight != null) {
          _myWeightEnabled = myWeight.source == 'override';
          _myWeight = myWeight.overrideWeight ?? myWeight.globalWeight;
          _globalWeight = myWeight.globalWeight;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = l10n.productLoadFailed;
        });
      }
    }
  }

  /// 搜索关联原料（供 Autocomplete.optionsBuilder 异步调用）。
  ///
  /// 中文 IME 会在一次提交前产生多个组合态文本；等待输入稳定后再请求，
  /// 避免中间拼音触发请求风暴并与最终中文结果竞争。
  Future<List<Ingredient>> _searchIngredients(String query) {
    final q = query.trim();
    // RawAutocomplete invokes optionsBuilder again when IME finalizes a
    // composition even though the text is unchanged. Reuse the in-flight
    // search instead of restarting it: a restarted future would be discarded
    // by the second call (shouldUpdateOptions is false), which left the
    // dropdown empty after the spinner stopped.
    if (q.isNotEmpty &&
        _ingredientSearchQuery == q &&
        _ingredientSearchCompleter != null &&
        !_ingredientSearchCompleter!.isCompleted) {
      return _ingredientSearchCompleter!.future;
    }

    final seq = ++_ingredientSearchSeq;
    _cancelPendingIngredientSearch();

    if (q.isEmpty) {
      if (mounted && _searching) setState(() => _searching = false);
      return Future.value(const <Ingredient>[]);
    }

    final completer = Completer<List<Ingredient>>();
    _ingredientSearchCompleter = completer;
    _ingredientSearchQuery = q;
    if (mounted) setState(() => _searching = true);
    _ingredientSearchDebounce = Timer(const Duration(milliseconds: 300),
        () async {
      try {
        final result = await _ingredientRepository.search(
          search: q,
          limit: 20,
        );
        final isCurrent = mounted && seq == _ingredientSearchSeq;
        if (isCurrent) setState(() => _searching = false);
        _completeIngredientSearch(
          completer,
          seq == _ingredientSearchSeq ? result.items : const <Ingredient>[],
        );
      } catch (_) {
        if (mounted && seq == _ingredientSearchSeq) {
          setState(() => _searching = false);
        }
        _completeIngredientSearch(completer, const <Ingredient>[]);
      }
    });
    return completer.future;
  }

  void _cancelPendingIngredientSearch() {
    _ingredientSearchDebounce?.cancel();
    _ingredientSearchDebounce = null;

    final completer = _ingredientSearchCompleter;
    _ingredientSearchCompleter = null;
    _ingredientSearchQuery = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(const <Ingredient>[]);
    }
  }

  void _completeIngredientSearch(
    Completer<List<Ingredient>> completer,
    List<Ingredient> result,
  ) {
    if (_ingredientSearchCompleter != completer) return;
    _ingredientSearchCompleter = null;
    _ingredientSearchQuery = null;
    if (!completer.isCompleted) completer.complete(result);
  }

  Future<void> _scanBarcode() async {
    final scanner = widget.scanner ?? showBarcodeScannerSheet;
    final code = await scanner(context);
    if (code == null || code.trim().isEmpty || !mounted) return;
    _barcodeController.text = code.trim();
    setState(() => _barcodeLoading = true);
    try {
      final result = await _productRepository.lookupBarcode(code);
      if (!mounted) return;
      if (!result.hasEnabledProviders) {
        return;
      }
      if (!result.found) return;
      setState(() {
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = result.product.name ?? '';
        }
        if (_brandController.text.trim().isEmpty) {
          _brandController.text = result.product.brand ?? '';
        }
      });
    } catch (_) {
      // 外部服务失败时保留扫码得到的条码，用户可以继续手工填写。
    } finally {
      if (mounted) setState(() => _barcodeLoading = false);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l10n.productNameRequired);
      return;
    }
    if (_selectedIngredient == null && !_createNewIngredient) {
      setState(() => _error = l10n.productSelectIngredientOrCreate);
      return;
    }
    if (_selectedIngredient == null && _createNewIngredient) {
      setState(() => _saving = true);
      try {
        final ingredient =
            await _ingredientRepository.createIngredient(name: name);
        _selectedIngredient = ingredient;
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = l10n.productCreateIngredientFailed;
            _saving = false;
          });
        }
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      Product? createdProduct;
      ProductMutationResult? result;
      if (_isEdit) {
        final ingredientChanged =
            _selectedIngredient!.id != _initialIngredientId;
        result = await _productRepository.updateProduct(
          widget.product!.id,
          isAdmin: widget.isAdmin,
          name: name,
          ingredientId: _selectedIngredient!.id,
          brand: _brandController.text.trim(),
          barcode: _barcodeController.text.trim(),
          aliases: _aliases,
          tags: _tags,
        );
        if (!mounted) return;
        // 只有变更真正落地（管理员直写）才调和：普通用户的换绑走待审，可能被驳回
        if (ingredientChanged && !result.pending) {
          // 换了关联原料：商品自定义单位里引用「旧原料单位」的行先改指向同名单位
          // （新原料同名 > 全局同名），实在没有同名单位才移除，并告知用户
          await _reconcileUnitsAfterIngredientChange(
            widget.product!.id,
            _selectedIngredient!.id,
            _initialIngredientId,
          );
          if (!mounted) return;
        }
      } else {
        createdProduct = await _productRepository.createProduct(
          name: name,
          ingredientId: _selectedIngredient!.id,
          brand: _brandController.text.trim(),
          barcode: _barcodeController.text.trim(),
          aliases: _aliases,
          tags: _tags,
        );
      }
      if (!mounted) return;
      if (!_isEdit) {
        // 商品已创建（拿到 id）→ 把自定义单位 / 营养信息草稿一并落库
        if (_draftUnits.isNotEmpty || _draftNutrients.isNotEmpty) {
          await _persistDrafts(createdProduct!.id);
          if (!mounted) return;
        }
        Navigator.of(context).pop(
          ProductFormResult(
            saved: true,
            pending: false,
            message: l10n.productCreated,
            product: createdProduct,
          ),
        );
        return;
      }
      // 我的权重覆盖：开关开 → set；关 → delete（用回全局）。
      // 个人偏好接口失败不阻塞保存，与 web 行为一致。
      try {
        if (_myWeightEnabled) {
          await _productRepository.setMyWeight(
            widget.product!.id,
            _myWeight,
          );
        } else {
          await _productRepository.deleteMyWeight(widget.product!.id);
        }
      } catch (_) {}
      if (!mounted) return;
      // 商品改名后后端会同步改写 product_records.product_name（快照列），
      // 但价格记录列表的客户端状态仍是旧的 → 必须主动重拉，否则要下拉刷新才更新。
      if (name != _initialName) _refreshPriceListAfterRename();
      if (!mounted) return;
      Navigator.of(context).pop(
        ProductFormResult(
          saved: true,
          pending: result!.pending,
          message: result.message,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.commonSaveFailedRetry;
        });
      }
    }
  }

  // ---------- 新增商品时的自定义单位 / 营养信息草稿 ----------

  /// 打开自定义单位草稿页前准备参照数据：全局单位（现拉，失败回退空）+ 关联原料
  /// 的单位与密度（用于继承引用与体积折算）。同一原料只加载一次。
  ///
  /// 只有全部必要数据都加载成功才缓存；失败的部分下次打开重试——
  /// 否则一次网络抖动会让本轮表单永远带不出关联原料的自定义单位。
  Future<void> _ensureDraftUnitReference() async {
    final ingredientId = _selectedIngredient?.id;
    if (_draftUnitsLoaded && _draftReferenceIngredientId == ingredientId) return;
    if (mounted) setState(() => _loadingDraftUnits = true);
    var globals = <GlobalUnitOption>[];
    var inherited = <EntityUnit>[];
    var density = 1000.0;
    var globalsLoaded = false;
    var inheritedLoaded = ingredientId == null;
    try {
      // listGlobalUnits 返回原始 Map（其它调用方只需要类型语义），这里转成下拉用的模型
      final rows = await _entityRepository.listGlobalUnits();
      globals = [for (final row in rows) GlobalUnitOption.fromJson(row)];
      globalsLoaded = true;
    } catch (error, stackTrace) {
      log('ProductFormScreen: 全局单位加载失败',
          name: 'product_form', error: error, stackTrace: stackTrace);
    }
    if (ingredientId != null) {
      try {
        inherited = await _entityRepository.listUnits('ingredient', ingredientId);
        inheritedLoaded = true;
      } catch (error, stackTrace) {
        log('ProductFormScreen: 关联原料单位加载失败',
            name: 'product_form', error: error, stackTrace: stackTrace);
      }
      try {
        final densities =
            await _entityRepository.listDensities('ingredient', ingredientId);
        if (densities.isNotEmpty && densities.first.density > 0) {
          density = densities.first.density;
        }
      } catch (error, stackTrace) {
        log('ProductFormScreen: 关联原料密度加载失败',
            name: 'product_form', error: error, stackTrace: stackTrace);
      }
    }
    if (!mounted) return;
    setState(() {
      _globalUnitOptions = globals;
      _inheritedUnits = inherited;
      _draftDensityKgM3 = density;
      _draftUnitsLoaded = globalsLoaded && inheritedLoaded;
      _draftReferenceIngredientId = ingredientId;
      _loadingDraftUnits = false;
    });
  }

  Future<void> _openDraftUnits() async {
    await _ensureDraftUnitReference();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => EntityUnitsDraftScreen(
          initialUnits: _draftUnits,
          inheritedUnits: _inheritedUnits,
          globalUnitOptions: _globalUnitOptions,
          effectiveDensityKgM3: _draftDensityKgM3,
          target: AppLocalizations.of(context).productDraftTargetProduct,
          onChanged: (units) {
            if (!mounted) return;
            setState(() {
              _draftUnits
                ..clear()
                ..addAll(units);
            });
          },
        ),
      ),
    );
  }

  /// 打开营养草稿页：USDA 匹配直写服务端，商品还不存在时必须关掉；
  /// 保存动作只把结果收进草稿（onSave 返回 null → 页面照常返回）。
  Future<void> _openDraftNutrition() async {
    await Navigator.of(context).push<NutritionEditResult>(
      MaterialPageRoute(
        builder: (ctx) => NutritionEditScreen(
          entityType: 'product',
          entityId: 0,
          initialNutrients: _draftNutrients,
          allowUsda: false,
          onSave: (entries) async {
            _draftNutrients = entries;
            return null;
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  /// 商品创建成功后把草稿一并落库，并按结果提示（失败不阻塞商品已保存的事实）。
  ///
  /// 即使勾选了「新建同名原料」，附加数据也写**商品层级**（原料只用于关联与引用）。
  Future<void> _persistDrafts(int productId) async {
    final persister = widget.draftPersister ??
        EntityDraftPersister(isAdmin: widget.isAdmin);
    final result = await persister.persist(
      entityType: 'product',
      entityId: productId,
      units: _draftUnits,
      nutrients: _draftNutrients,
    );
    if (!mounted) return;
    _notifyDraftResult(result);
  }

  void _notifyDraftResult(EntityDraftPersistResult result) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    for (final issue in result.issues) {
      final String text;
      switch (issue.kind) {
        case 'cycle':
          text = l10n.productDraftUnitCycle(issue.names.join(', '));
          break;
        case 'refMissing':
          text = l10n.productDraftUnitRefMissing(issue.names.join(', '));
          break;
        case 'unit':
          text = l10n.productDraftUnitFailed(
            issue.names.isEmpty ? '' : issue.names.first,
            issue.detail,
          );
          break;
        default:
          text = l10n.productDraftNutritionFailed(issue.detail);
      }
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
    if (result.hasExtras) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.productDraftExtrasSaved(
            l10n.productDraftTargetProduct,
            result.unitsCreated,
            result.nutrientsSaved,
          )),
        ),
      );
    } else if (result.hasPending) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(l10n.productDraftExtrasPending(l10n.productDraftTargetProduct)),
        ),
      );
    }
  }

  /// 新增态换绑关联原料后调和草稿单位：引用的单位在新原料里不存在时，
  /// 先按名字改指向「新原料的同名单位 / 全局同名单位」，实在没有同名单位才丢弃，
  /// 并提示用户 —— 草稿还没落库，本地改动没有服务端副作用。
  /// 编辑态不在这里处理：那时是服务端数据，必须等保存落地后才能动。
  Future<void> _reconcileDraftUnitsForIngredient(
    int newIngredientId,
    int? previousIngredientId,
  ) async {
    if (_draftUnits.isEmpty) return;
    List<EntityUnit> targetUnits;
    List<GlobalUnitOption> globals;
    var missingRefNames = <int, String>{};
    try {
      targetUnits =
          await _entityRepository.listUnits('ingredient', newIngredientId);
      final rows = await _entityRepository.listGlobalUnits();
      globals = [for (final row in rows) GlobalUnitOption.fromJson(row)];
      missingRefNames = await _unitNamesOfIngredient(previousIngredientId);
    } catch (error, stackTrace) {
      // 读取失败不动数据（宁可留着悬空引用，也不误改用户刚填的草稿）
      log('ProductFormScreen: 换原料后加载单位参照失败',
          name: 'product_form', error: error, stackTrace: stackTrace);
      return;
    }
    final result = reconcileUnitsAfterIngredientChange(
      units: _draftUnits,
      targetIngredientIdsByName: _unitIdsByName(targetUnits),
      globalIdsByName: _globalIdsByName(globals),
      missingRefNames: missingRefNames,
    );
    if (result.retargeted.isEmpty && result.removed.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _draftUnits
        ..clear()
        ..addAll(result.units);
    });
    _notifyIngredientChangeReconcile(result.retargeted, result.removed);
  }

  /// 旧原料的单位 id → 名字（用于给悬空引用找同名单位）。失败返回空表。
  Future<Map<int, String>> _unitNamesOfIngredient(int? ingredientId) async {
    if (ingredientId == null) return {};
    try {
      final units = await _entityRepository.listUnits('ingredient', ingredientId);
      return {for (final unit in units) unit.id: unit.unitName};
    } catch (error, stackTrace) {
      log('ProductFormScreen: 加载旧原料单位失败',
          name: 'product_form', error: error, stackTrace: stackTrace);
      return {};
    }
  }

  Map<String, int> _unitIdsByName(List<EntityUnit> units) {
    final map = <String, int>{};
    for (final unit in units) {
      final name = unit.unitName.trim();
      if (name.isNotEmpty) map.putIfAbsent(name, () => unit.id);
    }
    return map;
  }

  Map<String, int> _globalIdsByName(List<GlobalUnitOption> globals) {
    final map = <String, int>{};
    for (final option in globals) {
      final name = option.name.trim();
      if (name.isNotEmpty) map.putIfAbsent(name, () => option.id);
    }
    return map;
  }

  void _notifyIngredientChangeReconcile(
    List<EntityUnit> retargeted,
    List<EntityUnit> removed,
  ) {
    final l10n = AppLocalizations.of(context);
    final parts = <String>[];
    if (retargeted.isNotEmpty) {
      parts.add(l10n.productDanglingUnitsRetargeted(
        retargeted.map((unit) => unit.unitName).join(', '),
      ));
    }
    if (removed.isNotEmpty) {
      parts.add(l10n.productDanglingUnitsRemoved(
        removed.map((unit) => unit.unitName).join(', '),
      ));
    }
    if (parts.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(parts.join(' · '))),
    );
  }

  /// 换绑关联原料后调和商品自定义单位：引用在新原料里不存在时先改指向同名单位
  /// （新原料的同名单位优先，其次全局同名单位），实在没有才删除；普通用户的
  /// 删除/修改走待审。失败只留痕，不阻塞保存流程。
  Future<void> _reconcileUnitsAfterIngredientChange(
    int productId,
    int targetIngredientId,
    int? previousIngredientId,
  ) async {
    List<EntityUnit> productUnits;
    List<EntityUnit> targetUnits;
    List<GlobalUnitOption> globals;
    var missingRefNames = <int, String>{};
    try {
      productUnits = await _entityRepository.listUnits('product', productId);
      targetUnits =
          await _entityRepository.listUnits('ingredient', targetIngredientId);
      final rows = await _entityRepository.listGlobalUnits();
      globals = [for (final row in rows) GlobalUnitOption.fromJson(row)];
      if (previousIngredientId != null &&
          previousIngredientId != targetIngredientId) {
        missingRefNames = await _unitNamesOfIngredient(previousIngredientId);
      }
    } catch (error, stackTrace) {
      log('ProductFormScreen: 换原料后加载商品单位失败',
          name: 'product_form', error: error, stackTrace: stackTrace);
      return;
    }
    final result = reconcileUnitsAfterIngredientChange(
      units: productUnits,
      targetIngredientIdsByName: _unitIdsByName(targetUnits),
      globalIdsByName: _globalIdsByName(globals),
      missingRefNames: missingRefNames,
    );
    if (result.retargeted.isEmpty && result.removed.isEmpty) return;
    var pending = false;
    for (final unit in result.retargeted) {
      try {
        final write = await _entityRepository.updateUnit(
          'product',
          productId,
          unit.id,
          weightUnitId: unit.weightUnitId,
          weightUnitOverrideId: unit.weightUnitOverrideId,
        );
        if (write.pending) pending = true;
      } catch (error, stackTrace) {
        log('ProductFormScreen: 改指向自定义单位失败',
            name: 'product_form', error: error, stackTrace: stackTrace);
      }
    }
    for (final unit in result.removed) {
      try {
        final write =
            await _entityRepository.deleteUnit('product', productId, unit.id);
        if (write.pending) pending = true;
      } catch (error, stackTrace) {
        log('ProductFormScreen: 移除引用失效的自定义单位失败',
            name: 'product_form', error: error, stackTrace: stackTrace);
      }
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final parts = <String>[];
    if (result.retargeted.isNotEmpty) {
      parts.add(l10n.productDanglingUnitsRetargeted(
        result.retargeted.map((unit) => unit.unitName).join(', '),
      ));
    }
    if (result.removed.isNotEmpty) {
      final names = result.removed.map((unit) => unit.unitName).join(', ');
      parts.add(pending
          ? l10n.productDanglingUnitsRemovePending(names)
          : l10n.productDanglingUnitsRemoved(names));
    }
    if (parts.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(parts.join(' · '))),
    );
  }

  /// 改名成功后刷新价格记录列表（商品名快照列已被后端改写）。
  ///
  /// 不 await：列表刷新不该阻塞表单返回；失败只写日志（[loadRecords] 自身已把
  /// API 错误收进 state.error，这里兜底非 Exception 的意外）。
  void _refreshPriceListAfterRename() {
    if (!mounted) return;
    try {
      unawaited(
        ref.read(priceListProvider.notifier).loadRecords().catchError(
          (Object error, StackTrace stackTrace) {
            _logPriceListRefreshFailure(error, stackTrace);
          },
        ),
      );
    } catch (error, stackTrace) {
      _logPriceListRefreshFailure(error, stackTrace);
    }
  }

  void _logPriceListRefreshFailure(Object error, StackTrace stackTrace) {
    log(
      'ProductFormScreen: 改名后刷新价格列表失败',
      name: 'product_form',
      error: error,
      stackTrace: stackTrace,
    );
  }

  Widget _buildIngredientField() {
    final l10n = AppLocalizations.of(context);
    if (widget.fixedIngredient != null && !_isEdit) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.productLinkedIngredient,
          border: const OutlineInputBorder(),
        ),
        child: Row(
          children: [
            const Icon(Icons.link, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.fixedIngredient!.name)),
          ],
        ),
      );
    }

    // 下拉带输入的关联原料选择（对齐 price_record_form_screen 商家选择做法）。
    return Autocomplete<Ingredient>(
      textEditingController: _ingredientSearchController,
      focusNode: _ingredientFocusNode,
      optionsBuilder: (textEditingValue) async {
        final query = textEditingValue.text.trim();
        // 当前文本就是已选原料名时不再搜索（避免编辑态预填触发查询）。
        if (query.isEmpty ||
            (_selectedIngredient != null &&
                _selectedIngredient!.name == query)) {
          _cancelPendingIngredientSearch();
          if (_searching) setState(() => _searching = false);
          return const <Ingredient>[];
        }
        return _searchIngredients(query);
      },
      displayStringForOption: (ingredient) => ingredient.name,
      onSelected: (ingredient) {
        final previousIngredientId = _lastSelectedIngredientId;
        _lastSelectedIngredientId = ingredient.id;
        _ingredientSearchController.text = ingredient.name;
        setState(() {
          _selectedIngredient = ingredient;
          _searching = false;
        });
        // 新增态：换原料后草稿里引用「旧原料独有单位」的行要先改指向同名单位，
        // 没有同名单位才去掉（草稿只在本地，改没有服务端副作用；编辑态在保存时做）
        unawaited(_reconcileDraftUnitsForIngredient(
          ingredient.id,
          previousIngredientId,
        ));
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final ingredient = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(ingredient.name),
                    onTap: () => onSelected(ingredient),
                  );
                },
              ),
            ),
          ),
        );
      },
      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: _isEdit
                ? l10n.productLinkedIngredient
                : l10n.productSearchIngredient,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onFieldSubmitted(),
          onChanged: (value) {
            // 文本被改动后不再信任原选择；要保留必须重新点选。
            if (_selectedIngredient != null &&
                _selectedIngredient!.name != value.trim()) {
              setState(() => _selectedIngredient = null);
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final savePosition = ref.watch(saveButtonPositionProvider);
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(
              _isEdit ? l10n.productEditTitle : l10n.productAddTitle,
            ),
            actions: [
              ...saveAppBarActions(
                position: savePosition,
                onSave: _saving ? null : _save,
                label: _saving ? l10n.commonSaving : l10n.commonSave,
              ),
            ],
          ),
          bottomNavigationBar: saveBottomBar(
            context: context,
            position: savePosition,
            onSave: _saving ? null : _save,
            label: _saving ? l10n.commonSaving : l10n.commonSave,
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextFormField(
                      controller: _nameController,
                      initialValue: null,
                      decoration: InputDecoration(
                        labelText: l10n.productName,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_createNewIngredient) _buildIngredientField(),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l10n.productCreateSameName),
                      subtitle: Text(l10n.productCreateSameNameHint),
                      value: _createNewIngredient,
                      onChanged: (v) =>
                          setState(() => _createNewIngredient = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _brandController,
                      initialValue: null,
                      decoration: InputDecoration(
                        labelText: l10n.productBrand,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _barcodeController,
                      initialValue: null,
                      decoration: InputDecoration(
                        labelText: l10n.productBarcode,
                        border: const OutlineInputBorder(),
                        suffixIcon: _barcodeLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                tooltip: l10n.productScanBarcode,
                                icon: const Icon(Icons.barcode_reader),
                                onPressed: _scanBarcode,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AliasTagsField(
                      label: l10n.ingredientAliases,
                      initialTags: _aliases,
                      onTagsChanged: (aliases) => _aliases = aliases,
                    ),
                    if (!_isEdit) ...[
                      const SizedBox(height: 16),
                      // 自定义单位 / 营养信息：在这里先填好，保存商品时一并保存
                      Card(
                        margin: EdgeInsets.zero,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.straighten),
                              title: Text(_draftUnits.isEmpty
                                  ? l10n.productDraftUnitsButton
                                  : l10n.productDraftUnitsButtonCount(
                                      _draftUnits.length)),
                              subtitle: Text(
                                  l10n.productDraftSavedTogether(
                                      l10n.productDraftTargetProduct)),
                              trailing: _loadingDraftUnits
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.chevron_right),
                              onTap: _saving ? null : _openDraftUnits,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.food_bank_outlined),
                              title: Text(_draftNutrientCount == 0
                                  ? l10n.productDraftNutritionButton
                                  : l10n.productDraftNutritionButtonCount(
                                      _draftNutrientCount)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _saving ? null : _openDraftNutrition,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_isEdit) ...[
                      const SizedBox(height: 16),
                      AliasTagsField(
                        label: l10n.productTags,
                        initialTags: _tags,
                        onTagsChanged: (tags) => _tags = tags,
                      ),
                      const SizedBox(height: 8),
                      // 我的权重覆盖：开关 + 滑块（所有人可设，仅影响自己）
                      SwitchListTile(
                        title: Text(l10n.productMyWeightOverride),
                        subtitle:
                            Text(l10n.productMyWeightGlobalDefault(_globalWeight)),
                        value: _myWeightEnabled,
                        onChanged: (v) =>
                            setState(() => _myWeightEnabled = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_myWeightEnabled)
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _myWeight.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 100,
                                label: '$_myWeight',
                                onChanged: (v) =>
                                    setState(() => _myWeight = v.round()),
                              ),
                            ),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '$_myWeight',
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        if (_barcodeLoading) LoadingOverlay(message: l10n.productLookupLoading),
      ],
    );
  }
}
