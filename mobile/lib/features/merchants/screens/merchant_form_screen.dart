import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/region_select_field.dart';
import '../models/merchant.dart';
import '../repositories/merchant_repository.dart';
import '../widgets/map_point_picker.dart';

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

  const MerchantFormScreen({
    super.key,
    this.merchant,
    required this.isAdmin,
    this.repository,
    this.mapTileProvider,
  });

  @override
  ConsumerState<MerchantFormScreen> createState() => _MerchantFormScreenState();
}

class _MerchantFormScreenState extends ConsumerState<MerchantFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late bool _isOpen;
  LatLng? _coordinate;
  bool _saving = false;
  int? _regionId;
  String? _defaultCurrency;
  List<dynamic> _currencies = const [];

  @override
  void initState() {
    super.initState();
    final merchant = widget.merchant;
    _nameController = TextEditingController(text: merchant?.name ?? '');
    _addressController = TextEditingController(text: merchant?.address ?? '');
    _isOpen = merchant?.isOpen ?? true;
    _regionId = merchant?.regionId;
    _defaultCurrency = merchant?.defaultCurrency;
    _loadCurrencies();
    if (merchant?.latitude != null && merchant?.longitude != null) {
      _coordinate = LatLng(merchant!.latitude!, merchant.longitude!);
    }
  }

  @override
  void dispose() {
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

  Future<void> _onMapChanged(LatLng value) async {
    setState(() => _coordinate = value);
    final repository = widget.repository ?? MerchantRepository();
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
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入商家名称')),
      );
      return;
    }
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
        const MerchantFormResult(
          saved: true,
          pending: false,
          message: '已创建商家',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.merchant != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? '编辑商家' : '添加商家'),
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
                decoration: const InputDecoration(
                  labelText: '商家名称 *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '地址',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('营业中'),
                value: _isOpen,
                onChanged:
                    _saving ? null : (value) => setState(() => _isOpen = value),
              ),
              const SizedBox(height: 12),
              RegionSelectField(
                value: _regionId,
                onChanged: (v) => setState(() => _regionId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _defaultCurrency,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('跟随地区'),
                  ),
                  for (final c in _currencies)
                    DropdownMenuItem<String?>(
                      value: c['code'] as String?,
                      child: Text('${c['symbol']} ${c['name']}'),
                    ),
                ],
                decoration: const InputDecoration(
                  labelText: '默认币种',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _defaultCurrency = v),
              ),
              Text(
                '位置（点击地图选择，可选）',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              MapPointPicker(
                initialValue: _coordinate,
                onChanged: _saving ? null : _onMapChanged,
                tileProvider: widget.mapTileProvider,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(editing ? '保存' : '创建'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
