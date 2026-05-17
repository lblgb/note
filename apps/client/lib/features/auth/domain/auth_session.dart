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

// AuthDevice 表示服务端登记后的当前设备信息。
class AuthDevice {
  const AuthDevice({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.platform,
  });

  final String id;
  final String userId;
  final String deviceName;
  final String platform;

  // fromJson 从 JSON 对象解析设备信息。
  factory AuthDevice.fromJson(Map<String, Object?> json) {
    return AuthDevice(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
    );
  }

  // toJson 将设备信息转换为 JSON 对象。
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'userId': userId,
      'deviceName': deviceName,
      'platform': platform,
    };
  }
}

// AuthSession 表示本地保存的认证会话。
class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
    this.device,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;
  final AuthDevice? device;

  // fromJson 从 JSON 对象解析认证会话。
  factory AuthSession.fromJson(Map<String, Object?> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, Object?>? ?? {}),
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      device: json['device'] is Map<String, Object?>
          ? AuthDevice.fromJson(json['device'] as Map<String, Object?>)
          : null,
    );
  }

  // copyWithDevice 返回附带当前设备的新会话。
  AuthSession copyWithDevice(AuthDevice device) {
    return AuthSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      device: device,
    );
  }

  // copyWithTokens 返回替换访问令牌和刷新令牌的新会话。
  AuthSession copyWithTokens({
    required String accessToken,
    required String refreshToken,
  }) {
    return AuthSession(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      device: device,
    );
  }

  // toJson 将认证会话转换为 JSON 对象。
  Map<String, Object?> toJson() {
    return {
      'user': user.toJson(),
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      if (device != null) 'device': device!.toJson(),
    };
  }
}
