// 文件说明：提供账号登录和注册表单页面。
import 'package:flutter/material.dart';

typedef AuthLoginCallback =
    Future<void> Function({required String email, required String password});
typedef AuthRegisterCallback =
    Future<void> Function({
      required String email,
      required String password,
      required String displayName,
    });

const _authBg = Color(0xFFEEF8FB);
const _authPanel = Color(0xFFFFFFFF);
const _authLine = Color(0xFFD9E7EC);
const _authText = Color(0xFF103746);
const _authMuted = Color(0xFF627986);
const _authPrimary = Color(0xFF0891B2);

// AuthPage 展示登录和注册表单。
class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    required this.onLogin,
    required this.onRegister,
    this.errorMessage,
    this.isSubmitting = false,
  });

  final AuthLoginCallback onLogin;
  final AuthRegisterCallback onRegister;
  final String? errorMessage;
  final bool isSubmitting;

  // createState 创建认证表单状态。
  @override
  State<AuthPage> createState() => _AuthPageState();
}

// _AuthPageState 管理认证表单输入和模式切换。
class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  bool _isRegisterMode = false;

  // dispose 释放表单控制器。
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  // build 构建认证页面。
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _authBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _authPanel,
                  border: Border.all(color: _authLine),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isRegisterMode ? '注册账号' : '登录账号',
                        style: const TextStyle(
                          color: _authText,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '使用账号进入多端同步笔记。',
                        style: TextStyle(color: _authMuted, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      if (_isRegisterMode) ...[
                        TextField(
                          controller: _displayNameController,
                          decoration: const InputDecoration(labelText: '显示名称'),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: '邮箱'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: '密码'),
                        obscureText: true,
                        onSubmitted: (_) => _submit(),
                      ),
                      if (widget.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          widget.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: widget.isSubmitting ? null : _submit,
                        child: Text(
                          widget.isSubmitting
                              ? '处理中...'
                              : _isRegisterMode
                              ? '注册'
                              : '登录',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: widget.isSubmitting ? null : _toggleMode,
                        child: Text(
                          _isRegisterMode ? '已有账号，去登录' : '注册',
                          style: const TextStyle(color: _authPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // _toggleMode 切换登录和注册模式。
  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
    });
  }

  // _submit 提交当前模式下的认证表单。
  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_isRegisterMode) {
      await widget.onRegister(
        email: email,
        password: password,
        displayName: _displayNameController.text.trim(),
      );
      return;
    }
    await widget.onLogin(email: email, password: password);
  }
}
