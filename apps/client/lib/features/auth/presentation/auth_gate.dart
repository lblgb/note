// 文件说明：根据本地认证会话切换登录页和已登录应用内容。
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/auth_api_client.dart';
import '../data/auth_session_store.dart';
import '../domain/auth_session.dart';
import 'auth_page.dart';

typedef AuthenticatedBuilder =
    Widget Function(
      BuildContext context,
      AuthSession session,
      VoidCallback logout,
    );

typedef AuthDeviceProfileProvider = AuthDeviceProfile Function();

// AuthDeviceProfile 表示客户端本机设备登记信息。
class AuthDeviceProfile {
  const AuthDeviceProfile({required this.deviceName, required this.platform});

  final String deviceName;
  final String platform;
}

// AuthGate 负责加载会话、处理登录注册和退出登录。
class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.apiClient,
    required this.sessionStore,
    required this.authenticatedBuilder,
    this.deviceProfileProvider = _defaultDeviceProfile,
  });

  final AuthApiClient apiClient;
  final AuthSessionStore sessionStore;
  final AuthenticatedBuilder authenticatedBuilder;
  final AuthDeviceProfileProvider deviceProfileProvider;

  // createState 创建认证入口状态。
  @override
  State<AuthGate> createState() => _AuthGateState();
}

// _AuthGateState 管理认证会话和认证请求状态。
class _AuthGateState extends State<AuthGate> {
  AuthSession? _session;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // initState 启动时读取本地会话。
  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  // build 根据认证状态构建页面。
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    if (session != null) {
      return widget.authenticatedBuilder(context, session, _logout);
    }

    return AuthPage(
      isSubmitting: _isSubmitting,
      errorMessage: _errorMessage,
      onLogin: _login,
      onRegister: _register,
    );
  }

  // _loadSession 从本地存储读取会话。
  Future<void> _loadSession() async {
    final session = await widget.sessionStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = session;
      _isLoading = false;
    });
  }

  // _login 调用登录接口并保存会话。
  Future<void> _login({required String email, required String password}) async {
    await _authenticate(
      () => widget.apiClient.login(email: email, password: password),
    );
  }

  // _register 调用注册接口并保存会话。
  Future<void> _register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _authenticate(
      () => widget.apiClient.register(
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  // _authenticate 执行认证请求并处理成功或失败状态。
  Future<void> _authenticate(Future<AuthSession> Function() action) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final session = await action();
      final deviceProfile = widget.deviceProfileProvider();
      final device = await widget.apiClient.registerDevice(
        accessToken: session.accessToken,
        deviceName: deviceProfile.deviceName,
        platform: deviceProfile.platform,
      );
      final sessionWithDevice = session.copyWithDevice(device);
      await widget.sessionStore.save(sessionWithDevice);
      if (!mounted) {
        return;
      }
      setState(() {
        _session = sessionWithDevice;
        _isSubmitting = false;
      });
    } on AuthApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    }
  }

  // _logout 清除服务端和本地会话。
  Future<void> _logout() async {
    final session = _session;
    if (session != null) {
      try {
        await widget.apiClient.logout(session.refreshToken);
      } on AuthApiException {
        // 本地退出优先，服务端失败时也清理本地会话。
      }
    }
    await widget.sessionStore.clear();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
      _errorMessage = null;
      _isSubmitting = false;
    });
  }
}

// _defaultDeviceProfile 按运行平台返回默认设备登记信息。
AuthDeviceProfile _defaultDeviceProfile() {
  if (Platform.isAndroid) {
    return const AuthDeviceProfile(
      deviceName: 'Android 设备',
      platform: 'android',
    );
  }
  if (Platform.isWindows) {
    return const AuthDeviceProfile(
      deviceName: 'Windows 设备',
      platform: 'windows',
    );
  }
  return const AuthDeviceProfile(deviceName: '当前设备', platform: 'unknown');
}
