import 'user.dart';

/// PUT /auth/me/account 响应：改了密码才签发新 token，否则为 null。
class UserAccountResponse {
  final User user;
  final String? accessToken;
  final String? refreshToken;

  const UserAccountResponse({
    required this.user,
    this.accessToken,
    this.refreshToken,
  });

  factory UserAccountResponse.fromJson(Map<String, dynamic> json) {
    return UserAccountResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
    );
  }
}
