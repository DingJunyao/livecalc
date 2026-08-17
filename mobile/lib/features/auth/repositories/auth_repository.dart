import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_client.dart';
import '../models/account_response.dart';
import '../models/auth_config.dart';
import '../models/login_request.dart';
import '../models/user.dart';

class AuthRepository {
  final ApiClient _client;

  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  Future<AuthConfig> getConfig() async {
    final response = await _client.dio.get('/auth/config');
    return AuthConfig.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LoginResponse> login(LoginRequest request) async {
    final response =
        await _client.dio.post('/auth/login', data: request.toJson());
    return LoginResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LoginResponse> register({
    required String username,
    required String email,
    required String passwordHash,
    String? phone,
    String? inviteCode,
  }) async {
    final data = <String, dynamic>{
      'username': username,
      'email': email,
      'password_hash': passwordHash
    };
    if (phone != null) data['phone'] = phone;
    if (inviteCode != null) data['invite_code'] = inviteCode;
    final response = await _client.dio.post('/auth/register', data: data);
    return LoginResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<User> getCurrentUser() async {
    final response = await _client.dio.get('/auth/me');
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// 更新个人设置（营养目标/预算/单位偏好），只传变化字段。
  Future<User> updateMe(Map<String, dynamic> body) async {
    final response = await _client.dio.patch('/auth/me', data: body);
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  /// 更新账号信息（用户名/邮箱/手机/昵称），返回用户 + 可能的新 token。
  Future<UserAccountResponse> updateAccount(Map<String, dynamic> body) async {
    final response = await _client.dio.put('/auth/me/account', data: body);
    return UserAccountResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// 上传头像。注意：dio 全局默认 Content-Type 是 application/json，
  /// multipart 请求必须显式覆盖，否则后端 422。
  /// 用 readAsBytes 而非 fromFile，web 平台（blob 路径）也能上传。
  Future<void> uploadAvatar(XFile file) async {
    final bytes = await file.readAsBytes();
    await _client.dio.post(
      '/auth/me/avatar',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
      }),
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
  }
}
