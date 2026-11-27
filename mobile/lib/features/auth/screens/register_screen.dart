import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/shell_app_bar.dart';
import '../models/auth_config.dart';
import '../providers/auth_provider.dart';
import '../../profile/providers/startup_page_provider.dart';
import '../../../l10n/app_localizations.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with WidgetsBindingObserver {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeFocus = FocusNode();
  Timer? _configTimer;
  bool _submitting = false;
  bool _agreedToLegal = false;
  String? _configError;

  static const _configPollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(authProvider.notifier).clearError();
      _startConfigPolling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _configTimer?.cancel();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _inviteCodeController.dispose();
    _inviteCodeFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshConfig();
  }

  void _startConfigPolling() {
    _refreshConfig();
    _configTimer?.cancel();
    _configTimer = Timer.periodic(
      _configPollInterval,
      (_) => _refreshConfig(),
    );
  }

  Future<AuthConfig?> _refreshConfig() async {
    try {
      ref.invalidate(authConfigProvider);
      final config = await ref.read(authConfigProvider.future);
      if (mounted) setState(() => _configError = null);
      return config;
    } on Exception {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => _configError = l10n.authConfigLoadFailed);
      }
      return null;
    }
  }

  Future<void> _register() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    // 隐私政策/用户协议同意是注册前置条件（PIPL 告知-同意；App Store 5.1.1）
    if (!_agreedToLegal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).legalAgreeRequired)),
      );
      return;
    }
    setState(() {
      _submitting = true;
      _configError = null;
    });

    final previouslyRequired = _inviteRequired;
    final config = await _refreshConfig();
    if (!mounted) return;
    if (config == null) {
      setState(() => _submitting = false);
      return;
    }

    final inviteRequired = config.requireInviteCode;
    final inviteCode = _inviteCodeController.text.trim();
    if (inviteRequired && inviteCode.isEmpty) {
      setState(() {
        _submitting = false;
        if (!previouslyRequired) {
          _configError = AppLocalizations.of(context).authInviteCodeNowRequired;
        }
      });
      _inviteCodeFocus.requestFocus();
      return;
    }

    final success = await ref.read(authProvider.notifier).register(
          username: _usernameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          inviteCode:
              inviteRequired ? (inviteCode.isEmpty ? null : inviteCode) : null,
        );
    if (success && mounted) {
      context.go('/${ref.read(startupPageProvider)}');
      return;
    }
    // The server setting can change after the preflight GET; refresh again so
    // a newly required invite field appears immediately after the rejection.
    await _refreshConfig();
    if (mounted) setState(() => _submitting = false);
  }

  /// 注册页的《隐私政策》《用户协议》内联链接（打开应用内全文页）。
  Widget _legalLink(
      BuildContext context, String text, String route, ThemeData theme) {
    return InkWell(
      onTap: () => context.push(route),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  bool get _inviteRequired =>
      ref.watch(authConfigProvider).valueOrNull?.requireInviteCode ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final authConfig = ref.watch(authConfigProvider);
    final inviteRequired = _inviteRequired;
    final canSubmit = !_submitting &&
        authState.status != AuthStatus.loading &&
        !(authConfig.isLoading && authConfig.value == null);

    return Scaffold(
      appBar: ShellAppBar(title: Text(l10n.authRegisterTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                      labelText: l10n.authUsername,
                      prefixIcon: const Icon(Icons.person_outline)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.authUsernameRequired;
                    }
                    if (v.trim().length < 3) return l10n.authUsernameMinLength;
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => canSubmit ? _register() : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                      labelText: l10n.authEmail,
                      prefixIcon: const Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.authEmailRequired;
                    }
                    if (!v.contains('@')) return l10n.authEmailInvalid;
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => canSubmit ? _register() : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: l10n.authPassword,
                      prefixIcon: const Icon(Icons.lock_outline)),
                  validator: (v) =>
                      v == null || v.isEmpty ? l10n.authPasswordRequired : null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => canSubmit ? _register() : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                      labelText: l10n.authPhoneOptional,
                      prefixIcon: const Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => canSubmit ? _register() : null,
                ),
                const SizedBox(height: 8),
                if (inviteRequired) ...[
                  TextFormField(
                    controller: _inviteCodeController,
                    focusNode: _inviteCodeFocus,
                    decoration: InputDecoration(
                        labelText: l10n.authInviteCode,
                        prefixIcon: const Icon(Icons.card_giftcard_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l10n.authInviteCodeRequired
                        : null,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => canSubmit ? _register() : null,
                  ),
                ],
                if (_configError != null) ...[
                  const SizedBox(height: 8),
                  Text(_configError!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 8),
                if (authState.message != null)
                  Text(authState.message!.localized(l10n),
                      style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
                // 隐私政策 / 用户协议同意（可点开全文）
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Checkbox(
                        value: _agreedToLegal,
                        onChanged: (v) =>
                            setState(() => _agreedToLegal = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(l10n.legalAgreePrefix,
                                style: theme.textTheme.bodySmall),
                            _legalLink(
                              context,
                              l10n.legalPrivacyPolicy,
                              '/legal/privacy',
                              theme,
                            ),
                            Text(l10n.legalAgreeAnd,
                                style: theme.textTheme.bodySmall),
                            _legalLink(
                              context,
                              l10n.legalTermsOfService,
                              '/legal/terms',
                              theme,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: canSubmit ? _register : null,
                  child: authState.status == AuthStatus.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.authRegisterButton),
                ),
                const SizedBox(height: 16),
                TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(l10n.authHaveAccountLogin)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
