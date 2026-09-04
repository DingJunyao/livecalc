import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/services/server_connection_checker.dart';
import '../providers/auth_provider.dart';
import '../providers/server_provider.dart';
import '../../../l10n/app_localizations.dart';

class ServerConfigScreen extends ConsumerStatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  ConsumerState<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends ConsumerState<ServerConfigScreen> {
  final _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(serverConfigProvider.notifier).load().then((_) {
      final saved = ref.read(serverConfigProvider);
      if (saved != null && _urlController.text.isEmpty) {
        _urlController.text = saved;
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = _urlController.text.trim();
      ApiClient.instance.updateBaseUrl(url);
      final connected = await ServerConnectionChecker.verify();
      if (!connected) {
        setState(() => _error = l10n.authCannotConnectServer);
        return;
      }
      await ref.read(serverConfigProvider.notifier).setUrl(url);
      ref.read(authProvider.notifier).clearConnectionError();
      if (mounted) context.go('/login');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final effectiveError = _error ??
        (authState.serverUnreachable
            ? authState.message?.localized(l10n)
            : null);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: SvgPicture.asset('assets/images/logo.svg'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.appBrandShort,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(l10n.authServerConfigSubtitle,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: l10n.authServerAddress,
                      hintText: l10n.authServerAddressHint,
                      prefixIcon: const Icon(Icons.dns_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _loading ? null : _connect(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return l10n.authServerAddressRequired;
                      }
                      if (!v.trim().startsWith('http')) {
                        return l10n.authServerAddressHttpRequired;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  if (effectiveError != null)
                    Column(
                      children: [
                        Text(l10n.authConnectionFailed,
                            style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold)),
                        Text(effectiveError,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.error))
                      ],
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _connect,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.authConnect),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
