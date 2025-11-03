/* import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class AuthService {
  final Map<String, _StoredUser> _usersByEmail = {};
  UserModel? _currentUser;

  Future<UserModel> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final key = email.toLowerCase();
    final record = _usersByEmail[key];
    if (record == null || record.password != password) {
      throw Exception('邮箱或密码错误');
    }
    _currentUser = record.user;
    return record.user;
  }

  Future<UserModel> register(String email, String password, String username) async {
    await Future.delayed(const Duration(milliseconds: 300));
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
    return user;
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 150));
    _currentUser = null;
  }

  UserModel? get currentUser => _currentUser;

  String _genId() {
    final ms = DateTime.now().microsecondsSinceEpoch;
    return 'u_$ms';
  }
}

class _StoredUser {
  final UserModel user;
  final String password;
  _StoredUser({required this.user, required this.password});
} */