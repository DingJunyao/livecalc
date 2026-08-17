import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/auth_interceptor.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';

/// 编辑账号信息：头像（选图 + 方形裁剪 + 上传）+ 用户名/昵称/邮箱/手机。
/// 不做改密码（用户未要求，web 同入口也未放）。
class EditAccountScreen extends ConsumerStatefulWidget {
  /// 可注入以便测试；生产用默认实现。
  final AuthRepository? repository;

  const EditAccountScreen({super.key, this.repository});

  @override
  ConsumerState<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends ConsumerState<EditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _nickname;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  bool _uploading = false;
  bool _saving = false;

  AuthRepository get _repo => widget.repository ?? AuthRepository();

  User get _user => ref.read(authProvider).user!;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: _user.username);
    _nickname = TextEditingController(text: _user.nickname ?? '');
    _email = TextEditingController(text: _user.email);
    _phone = TextEditingController(text: _user.phone ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    _nickname.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    XFile? toUpload = picked;
    // image_cropper 仅 Android/iOS/Web 支持，其他平台直接上传原图。
    if (Platform.isAndroid || Platform.isIOS) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(toolbarTitle: '裁剪头像', lockAspectRatio: true),
          IOSUiSettings(),
        ],
      );
      if (cropped == null) return; // 用户取消裁剪
      toUpload = XFile(cropped.path);
    }

    setState(() => _uploading = true);
    try {
      await _repo.uploadAvatar(toUpload);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) _toast('头像已更新');
    } catch (_) {
      if (mounted) _toast('头像上传失败，请重试');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = _user;
    final body = <String, dynamic>{};
    final username = _username.text.trim();
    if (username != user.username) body['username'] = username;
    final nickname = _nickname.text.trim();
    if (nickname != (user.nickname ?? '')) body['nickname'] = nickname;
    final email = _email.text.trim();
    if (email != user.email) body['email'] = email;
    final phone = _phone.text.trim();
    if (phone != (user.phone ?? '')) body['phone'] = phone;
    if (body.isEmpty) {
      _toast('没有需要保存的修改');
      return;
    }

    setState(() => _saving = true);
    try {
      final resp = await _repo.updateAccount(body);
      if (resp.accessToken != null && resp.refreshToken != null) {
        await AuthInterceptor.saveTokens(resp.accessToken!, resp.refreshToken!);
      }
      ref.read(authProvider.notifier).applyUser(resp.user);
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

  /// 提取后端 400 detail（可能是字符串或验证错误列表）。
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
    final theme = Theme.of(context);
    final user = ref.watch(authProvider).user;
    final initial =
        user?.displayName.isNotEmpty == true ? user!.displayName[0] : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('编辑个人信息')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 头像区
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundImage: user?.avatarUrl != null
                            ? NetworkImage(user!.avatarUrl!)
                            : null,
                        onForegroundImageError:
                            user?.avatarUrl == null ? null : (_, __) {},
                        child: Text(initial,
                            style: theme.textTheme.headlineMedium),
                      ),
                      if (_uploading)
                        const Positioned.fill(
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _uploading ? null : _pickAvatar,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('点击更换头像'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: '用户名 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.length < 3 || t.length > 50) {
                  return '用户名长度需为 3-50 个字符';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nickname,
              decoration: const InputDecoration(
                labelText: '昵称',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if ((v?.trim().length ?? 0) > 50) return '昵称不能超过 50 个字符';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '邮箱',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty ||
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                  return '请输入有效的邮箱地址';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '手机号（可选）',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isNotEmpty && !RegExp(r'^1[3-9]\d{9}$').hasMatch(t)) {
                  return '请输入有效的手机号';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '保存中...' : '保存'),
            ),
          ],
        ),
      ),
    );
  }
}
