import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/server_provider.dart';
import '../../profile/providers/startup_page_provider.dart';
import '../../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).login(
          _usernameController.text.trim(),
          _passwordController.text,
        );
    if (success && mounted) context.go('/${ref.read(startupPageProvider)}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);
    final serverUrl = ref.watch(serverConfigProvider);

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
                  Icon(Icons.lock_outline,
                      size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(l10n.authLoginTitle,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(l10n.authLoginSubtitle,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                        labelText: l10n.authUsername,
                        prefixIcon: const Icon(Icons.person_outline)),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? l10n.authUsernameRequired
                        : null,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) =>
                        authState.status == AuthStatus.loading
                            ? null
                            : _login(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                        labelText: l10n.authPassword,
                        prefixIcon: const Icon(Icons.lock_outline)),
                    validator: (v) => v == null || v.isEmpty
                        ? l10n.authPasswordRequired
                        : null,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) =>
                        authState.status == AuthStatus.loading
                            ? null
                            : _login(),
                  ),
                  const SizedBox(height: 8),
                  if (authState.message != null)
                    Text(authState.message!.localized(l10n),
                        style: TextStyle(color: theme.colorScheme.error)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed:
                        authState.status == AuthStatus.loading ? null : _login,
                    child: authState.status == AuthStatus.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l10n.authLoginButton),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => context.go('/register'),
                      child: Text(l10n.authNoAccountRegister)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dns_outlined,
                          size: 13, color: theme.colorScheme.outline),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          serverUrl ?? l10n.authServerNotConfigured,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                      onPressed: () => context.go('/server-config'),
                      child: Text(l10n.authChangeServer)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
