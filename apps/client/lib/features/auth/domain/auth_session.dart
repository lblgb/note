// 文件说明：定义 Flutter 客户端认证用户和本地会话模型。

// AuthUser 表示服务端返回的登录用户信息。
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String displayName;

  // fromJson 从 JSON 对象解析用户信息。
  factory AuthUser.fromJson(Map<String, Object?> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
    );
  }

  // toJson 将用户信息转换为 JSON 对象。
  Map<String, Object?> toJson() {
    return {'id': id, 'email': email, 'displayName': displayName};
  }
}

// AuthSession 表示本地保存的认证会话。
class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;

  // fromJson 从 JSON 对象解析认证会话。
  factory AuthSession.fromJson(Map<String, Object?> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, Object?>? ?? {}),
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }

  // toJson 将认证会话转换为 JSON 对象。
  Map<String, Object?> toJson() {
    return {
      'user': user.toJson(),
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}
