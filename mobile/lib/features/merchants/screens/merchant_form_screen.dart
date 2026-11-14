import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/apple_maps_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/region_select_field.dart';
import '../models/merchant.dart';
import '../repositories/merchant_repository.dart';
import '../services/region_matcher.dart';
import '../widgets/map_point_picker.dart';
import '../../../shared/widgets/save_action_button.dart';
import '../../../shared/widgets/form_exit_guard.dart';
import '../../profile/providers/save_button_position_provider.dart';

class MerchantFormResult {
  final bool saved;
  final bool pending;
  final String message;

  const MerchantFormResult({
    required this.saved,
    required this.pending,
    required this.message,
  });
}

class MerchantFormArguments {
  final Merchant? merchant;
  final bool isAdmin;
  final MerchantRepository? repository;
  final TileProvider? mapTileProvider;

  const MerchantFormArguments({
    this.merchant,
    required this.isAdmin,
    this.repository,
    this.mapTileProvider,
  });
}

class MerchantFormScreen extends ConsumerStatefulWidget {
  final Merchant? merchant;
  final bool isAdmin;
  final MerchantRepository? repository;
  final TileProvider? mapTileProvider;
  final AppleMapsService? appleMapsService;

  const MerchantFormScreen({
    super.key,
    this.merchant,
    required this.isAdmin,
    this.repository,
    this.mapTileProvider,
    this.appleMapsService,
  });

  @override
  ConsumerState<MerchantFormScreen> createState() => _MerchantFormScreenState();
}

class _MerchantFormScreenState extends ConsumerState<MerchantFormScreen> {
  /// 名称/地址触发的苹果地图匹配防抖（300ms + 请求序号，旧响应作废）。
  static const _appleSearchDebounce = Duration(milliseconds: 300);

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late bool _isOpen;
  LatLng? _coordinate;
  bool _saving = false;
  int? _regionId;
  String? _defaultCurrency;
  List<dynamic> _currencies = const [];
  late final AppleMapsService _appleMaps;
  Timer? _nameDebounce;
  int _nameSeq = 0;
  Timer? _addressDebounce;
  int _addressSeq = 0;
  List<ApplePlace> _nameCandidates = const [];
  List<ApplePlace> _addressCandidates = const [];

  /// 新增态退出确认：进入页面时的字段快照（与当前值比对判断「写过信息」）。
  late final LatLng? _initialCoordinate;

  @override
  void initState() {
    super.initState();
    final merchant = widget.merchant;
    _nameController = TextEditingController(text: merchant?.name ?? '');
    _addressController = TextEditingController(text: merchant?.address ?? '');
    _isOpen = merchant?.isOpen ?? true;
    _regionId = merchant?.regionId;
    _defaultCurrency = merchant?.defaultCurrency;
    _appleMaps = widget.appleMapsService ?? AppleMapsService();
    _loadCurrencies();
    if (merchant?.latitude != null && merchant?.longitude != null) {
      _coordinate = LatLng(merchant!.latitude!, merchant.longitude!);
    }
    _initialCoordinate = _coordinate;
  }

  /// 是否在新增态下写过任何信息（名字/地址/开关/地区/币种/坐标任一变化）。
  bool get _hasUnsavedInput =>
      widget.merchant == null &&
      (_nameController.text.trim().isNotEmpty ||
          _addressController.text.trim().isNotEmpty ||
          _isOpen != true ||
          _regionId != null ||
          _defaultCurrency != null ||
          _coordinate != _initialCoordinate);

  /// 「已有」判定：占位坐标（默认中心 / (0,0)）不算已有，可被匹配结果覆盖。
  bool get _hasCoordinate => !isPlaceholderCoordinate(_coordinate);

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _addressDebounce?.cancel();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrencies() async {
    try {
      final response = await ApiClient.instance.dio.get('/currencies');
      final data = response.data;
      final list = (data is List)
          ? data
          : ((data is Map ? data['items'] as List? : null) ?? const []);
      final currencies = <Map<String, dynamic>>[
        for (final item in list)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
      if (!mounted) return;
      setState(() => _currencies = currencies);
    } catch (_) {
      // Currency list is optional; keep the fallback item available.
    }
  }

  /// 名称输入 → 苹果地图候选（仅 iOS，300ms 防抖 + 请求序号守卫）。
  void _onNameChanged(String value) {
    _nameDebounce?.cancel();
    final seq = ++_nameSeq;
    final query = value.trim();
    if (query.isEmpty) {
      if (_nameCandidates.isNotEmpty) {
        setState(() => _nameCandidates = const []);
      }
      return;
    }
    _nameDebounce = Timer(_appleSearchDebounce, () async {
      final results = await _appleMaps.searchPlaces(query, center: _coordinate);
      if (!mounted || seq != _nameSeq) return;
      setState(() => _nameCandidates = results);
    });
  }

  /// 地址输入 → 苹果地图候选（同名称流）。
  void _onAddressChanged(String value) {
    _addressDebounce?.cancel();
    final seq = ++_addressSeq;
    final query = value.trim();
    if (query.isEmpty) {
      if (_addressCandidates.isNotEmpty) {
        setState(() => _addressCandidates = const []);
      }
      return;
    }
    _addressDebounce = Timer(_appleSearchDebounce, () async {
      final results =
          await _appleMaps.searchPlaces(query, center: _coordinate);
      if (!mounted || seq != _addressSeq) return;
      setState(() => _addressCandidates = results);
    });
  }

  /// 点选匹配候选：只填空字段/占位值，已有值一律不覆盖。
  ///
  /// 名称流带出地址+坐标+行政区划；地址流带出坐标+行政区划（地址本身
  /// 就是搜索源，永不回写）。程序化赋值不触发 onChanged，无二次搜索循环。
  Future<void> _applyCandidate(ApplePlace place, {required bool fromName}) async {
    final repository = widget.repository ?? MerchantRepository();
    if (fromName) {
      _nameDebounce?.cancel();
      _nameSeq++;
    } else {
      _addressDebounce?.cancel();
      _addressSeq++;
    }
    setState(() {
      if (fromName) {
        _nameCandidates = const [];
      } else {
        _addressCandidates = const [];
      }
      if (fromName &&
          _addressController.text.trim().isEmpty &&
          place.address.isNotEmpty) {
        _addressController.text = place.address;
      }
      // 坐标已有（非占位）则保留；null/占位值由匹配结果覆盖。
      if (!_hasCoordinate &&
          place.latitude != null &&
          place.longitude != null) {
        _coordinate = LatLng(place.latitude!, place.longitude!);
      }
    });
    if (_regionId != null) return;
    final regionId = await matchRegionId(
      repository,
      countryCode: place.countryCode,
      country: place.country,
      administrativeArea: place.administrativeArea,
      locality: place.locality,
      subLocality: place.subLocality,
    );
    if (regionId != null && mounted && _regionId == null) {
      setState(() => _regionId = regionId);
    }
  }

  Future<void> _onMapChanged(LatLng value) async {
    setState(() => _coordinate = value);
    final repository = widget.repository ?? MerchantRepository();
    // iOS：原生 MapKit 逆编码（CLGeocoder），后端高德仅作失败回退。
    if (_appleMaps.isAvailable) {
      try {
        final place = await _appleMaps.reverseGeocodeForWgs84(
          value.latitude,
          value.longitude,
        );
        if (place != null) {
          final rid = await matchRegionId(
            repository,
            countryCode: place.countryCode,
            country: place.country,
            administrativeArea: place.administrativeArea,
            locality: place.locality,
            subLocality: place.subLocality,
          );
          if (rid != null && mounted) {
            setState(() => _regionId = rid);
            return;
          }
        }
      } catch (_) {
        // 原生逆编码失败，继续走后端回退。
      }
    }
    try {
      final rid = await repository.geocode(
        latitude: value.latitude,
        longitude: value.longitude,
      );
      if (rid != null && mounted) {
        setState(() => _regionId = rid);
      }
    } catch (_) {
      // Region reverse lookup is best-effort.
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    setState(() => _saving = true);
    final repository = widget.repository ?? MerchantRepository();
    try {
      if (widget.merchant == null) {
        await repository.createMerchant(
          name: name,
          address: _addressController.text.trim(),
          isOpen: _isOpen,
          latitude: _coordinate?.latitude,
          longitude: _coordinate?.longitude,
          regionId: _regionId,
          defaultCurrency: _defaultCurrency,
        );
      } else {
        final result = await repository.updateMerchant(
          widget.merchant!.id,
          isAdmin: widget.isAdmin,
          name: name,
          address: _addressController.text.trim(),
          isOpen: _isOpen,
          latitude: _coordinate?.latitude,
          longitude: _coordinate?.longitude,
          regionId: _regionId,
          defaultCurrency: _defaultCurrency,
        );
        if (!mounted) return;
        context.pop(
          MerchantFormResult(
            saved: true,
            pending: result.pending,
            message: result.message,
          ),
        );
        return;
      }
      if (!mounted) return;
      context.pop(
        MerchantFormResult(
          saved: true,
          pending: false,
          message: l10n.merchantCreated,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.merchantSaveFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 名称/地址输入触发的苹果地图匹配候选（仅 iOS 才会非空）。
  Widget _buildAppleCandidates(
    List<ApplePlace> items,
    ValueChanged<ApplePlace> onTap,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(
              l10n.appleMapsMatches,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final place = items[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: place.address.isEmpty
                      ? null
                      : Text(
                          place.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => onTap(place),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final editing = widget.merchant != null;
    final savePosition = ref.watch(saveButtonPositionProvider);
    final saveLabel = editing ? l10n.commonSave : l10n.merchantCreateButton;
    return FormExitGuard(
      enabled: !editing && !_saving,
      isDirty: () => _hasUnsavedInput,
      child: Scaffold(
        appBar: AppBar(
          title: Text(editing ? l10n.merchantEditTitle : l10n.merchantAddTitle),
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
                TextField(
                  controller: _nameController,
                  autofocus: !editing,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.merchantNameOptional,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged:
                      _appleMaps.isAvailable ? _onNameChanged : null,
                ),
                if (_nameCandidates.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildAppleCandidates(
                    _nameCandidates,
                    (place) => _applyCandidate(place, fromName: true),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.merchantAddress,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged:
                      _appleMaps.isAvailable ? _onAddressChanged : null,
                ),
                if (_addressCandidates.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildAppleCandidates(
                    _addressCandidates,
                    (place) => _applyCandidate(place, fromName: false),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.merchantIsOpen),
                  value: _isOpen,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _isOpen = value),
                ),
                const SizedBox(height: 12),
                RegionSelectField(
                  value: _regionId,
                  onChanged: (v) => setState(() => _regionId = v),
                  repository: widget.repository,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _defaultCurrency,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.merchantCurrencyFollowRegion),
                    ),
                    for (final c in _currencies)
                      DropdownMenuItem<String?>(
                        value: c['code'] as String?,
                        child: Text('${c['name']} ${c['code']}'),
                      ),
                  ],
                  // 收起时只显示三字母代码（未选时显示「跟随地区」）
                  selectedItemBuilder: (context) => [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.merchantCurrencyFollowRegion),
                    ),
                    for (final c in _currencies)
                      DropdownMenuItem<String?>(
                        value: c['code'] as String?,
                        child: Text(c['code'] as String),
                      ),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.merchantDefaultCurrency,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _defaultCurrency = v),
                ),
                Text(
                  l10n.merchantLocationPickerTitle,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                MapPointPicker(
                  initialValue: _coordinate,
                  onChanged: _saving ? null : _onMapChanged,
                  tileProvider: widget.mapTileProvider,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
