import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  static const _keyCurrentUser = 'auth_current_user';
  static const _keyUsersByEmail = 'auth_users_by_email';

  final Map<String, _StoredUser> _usersByEmail = {};
  UserModel? _currentUser;

  Future<void>? _hydrateFuture;

  Future<UserModel?> restoreSession() async {
    await _ensureHydrated();
    return _currentUser;
  }

  Future<UserModel> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _ensureHydrated();

    final identifier = email.trim().toLowerCase();

    // 管理员：用户名为 'carlo' 且密码为 '123456' 直接登录成功
    if (identifier == 'carlo' && password == '123456') {
      final user = UserModel(
        id: 'u_carlo',
        email: 'carlo@example.com',
        username: 'carlo',
        avatar: null,
        createdAt: DateTime.now(),
      );
      _currentUser = user;
      await _persistCurrentUser(user);
      return user;
    }

    final key = email.toLowerCase();
    final record = _usersByEmail[key];
    if (record == null || record.password != password) {
      throw Exception('邮箱或密码错误');
    }
    _currentUser = record.user;
    await _persistCurrentUser(record.user);
    return record.user;
  }

  Future<UserModel> register(String email, String password, String username) async {
    await Future.delayed(const Duration(milliseconds: 300));
    await _ensureHydrated();

    final key = email.toLowerCase();
    if (_usersByEmail.containsKey(key)) {
      throw Exception('该邮箱已注册');
    }
    final user = UserModel(
      id: _genId(),
      email: key,
      username: username,
      avatar: null,
      createdAt: DateTime.now(),
    );
    _usersByEmail[key] = _StoredUser(user: user, password: password);
    _currentUser = user;
    await _persistUsersByEmail();
    await _persistCurrentUser(user);
    return user;
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 150));
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentUser);
  }

  UserModel? get currentUser => _currentUser;

  Future<void> _ensureHydrated() {
    return _hydrateFuture ??= _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = await SharedPreferences.getInstance();

    final rawUsers = prefs.getString(_keyUsersByEmail);
    if (rawUsers != null && rawUsers.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUsers);
        if (decoded is Map) {
          _usersByEmail.clear();
          for (final entry in decoded.entries) {
            final email = entry.key.toString();
            final v = entry.value;
            if (v is Map) {
              final password = v['password'];
              final userJson = v['user'];
              if (password is String && userJson is Map) {
                _usersByEmail[email] = _StoredUser(
                  user: UserModel.fromJson(Map<String, dynamic>.from(userJson)),
                  password: password,
                );
              }
            }
          }
        }
      } catch (_) {
        await prefs.remove(_keyUsersByEmail);
        _usersByEmail.clear();
      }
    }

    final rawUser = prefs.getString(_keyCurrentUser);
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map) {
          _currentUser = UserModel.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        await prefs.remove(_keyCurrentUser);
        _currentUser = null;
      }
    }
  }

  Future<void> _persistCurrentUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
  }

  Future<void> _persistUsersByEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMap = <String, dynamic>{};
    for (final entry in _usersByEmail.entries) {
      jsonMap[entry.key] = {
        'password': entry.value.password,
        'user': entry.value.user.toJson(),
      };
    }
    await prefs.setString(_keyUsersByEmail, jsonEncode(jsonMap));
  }

  String _genId() {
    final ms = DateTime.now().microsecondsSinceEpoch;
    return 'u_$ms';
  }
}

class _StoredUser {
  final UserModel user;
  final String password;
  _StoredUser({required this.user, required this.password});
}