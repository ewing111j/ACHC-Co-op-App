// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthState _state = AuthState.initial;
  UserModel? _currentUser;
  String? _errorMessage;
  List<UserModel> _kids = [];

  AuthState get state => _state;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  List<UserModel> get kids => _kids;

  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isParent => _currentUser?.isParent ?? false;
  bool get isKid => _currentUser?.isKid ?? false;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      if (user != null) {
        _setState(AuthState.loading);
        final userData = await _authService.getUserData(user.uid);
        if (userData != null) {
          _currentUser = userData;
          if (userData.isParent) {
            await _loadKids();
          }
          _setState(AuthState.authenticated);
        } else {
          _setState(AuthState.unauthenticated);
        }
      } else {
        _currentUser = null;
        _kids = [];
        _setState(AuthState.unauthenticated);
      }
    });
  }

  Future<void> _loadKids() async {
    if (_currentUser == null) return;
    _kids = await _authService.getKidsForParent(_currentUser!.uid);
    notifyListeners();
  }

  Future<bool> signIn(String email, String password) async {
    _setState(AuthState.loading);
    try {
      final user = await _authService.signInWithEmailPassword(email, password);
      if (user != null) {
        _currentUser = user;
        if (user.isParent) await _loadKids();
        _setState(AuthState.authenticated);
        return true;
      }
      _setError('Sign in failed. Please try again.');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> signInAsKid(
      String parentEmail, String kidName, String password) async {
    _setState(AuthState.loading);
    try {
      final user =
          await _authService.signInAsKid(parentEmail, kidName, password);
      if (user != null) {
        _currentUser = user;
        _setState(AuthState.authenticated);
        return true;
      }
      _setError('Kid sign in failed. Please try again.');
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> register(
      String email, String password, String displayName) async {
    _setState(AuthState.loading);
    try {
      final user = await _authService.registerParent(
          email: email, password: password, displayName: displayName);
      if (user != null) {
        _currentUser = user;
        _setState(AuthState.authenticated);
        return true;
      }
      _setError('Registration failed. Please try again.');
      return false;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<bool> addKid(String kidName, String kidPassword) async {
    if (_currentUser == null || !_currentUser!.isParent) return false;
    try {
      final kid = await _authService.addKidToFamily(
        parent: _currentUser!,
        kidName: kidName,
        kidPassword: kidPassword,
      );
      if (kid != null) {
        _kids.add(kid);
        final updatedKidUids = [..._currentUser!.kidUids, kid.uid];
        _currentUser = _currentUser!.copyWith(kidUids: updatedKidUids);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> saveMoodleCredentials(
      String moodleUrl, String moodleToken) async {
    if (_currentUser == null) return;
    await _authService.saveMoodleCredentials(
        _currentUser!.uid, moodleUrl, moodleToken);
    _currentUser =
        _currentUser!.copyWith(moodleUrl: moodleUrl, moodleToken: moodleToken);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _kids = [];
    _setState(AuthState.unauthenticated);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setState(AuthState state) {
    _state = state;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _state = AuthState.error;
    notifyListeners();
  }
}
