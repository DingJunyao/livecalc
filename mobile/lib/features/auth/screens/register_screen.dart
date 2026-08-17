import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/auth_config.dart';
import '../providers/auth_provider.dart';
import '../../profile/providers/startup_page_provider.dart';

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
        setState(() => _configError = '注册配置加载失败，请检查网络后重试');
      }
      return null;
    }
  }

  Future<void> _register() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
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
          _configError = '注册失败：服务器已开启邀请码注册，请填写邀请码';
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

  bool get _inviteRequired =>
      ref.watch(authConfigProvider).valueOrNull?.requireInviteCode ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final authConfig = ref.watch(authConfigProvider);
    final inviteRequired = _inviteRequired;
    final canSubmit = !_submitting &&
        authState.status != AuthStatus.loading &&
        !(authConfig.isLoading && authConfig.value == null);

    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
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
                  decoration: const InputDecoration(
                      labelText: '用户名', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入用户名';
                    if (v.trim().length < 3) return '用户名至少 3 个字符';
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => canSubmit ? _register() : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                      labelText: '邮箱', prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入邮箱';
                    if (!v.contains('@')) return '邮箱格式不正确';
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => canSubmit ? _register() : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: '密码', prefixIcon: Icon(Icons.lock_outline)),
                  validator: (v) => v == null || v.isEmpty ? '请输入密码' : null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => canSubmit ? _register() : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                      labelText: '手机号（可选）',
                      prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => canSubmit ? _register() : null,
                ),
                const SizedBox(height: 8),
                if (inviteRequired) ...[
                  TextFormField(
                    controller: _inviteCodeController,
                    focusNode: _inviteCodeFocus,
                    decoration: const InputDecoration(
                        labelText: '邀请码',
                        prefixIcon: Icon(Icons.card_giftcard_outlined)),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '请输入邀请码' : null,
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
                if (authState.errorMessage != null)
                  Text(authState.errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: canSubmit ? _register : null,
                  child: authState.status == AuthStatus.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('注册'),
                ),
                const SizedBox(height: 16),
                TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('已有账号？去登录')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
