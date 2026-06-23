import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/rider.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final AnalyticsService _analyticsService;
  UserAccount? _currentUser;
  RiderProfile? _riderProfile;
  String? _token;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._apiService, this._analyticsService) {
    _apiService.onSessionExpired = () {
      logout();
    };
  }

  UserAccount? get currentUser => _currentUser;
  RiderProfile? get riderProfile => _riderProfile;
  String? get token => _token;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isRider => _currentUser?.role == 'RIDER';
  bool get isApproved => _riderProfile?.onboardingStatus == 'APPROVED';

  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.loadPersistedTokens();

      if (_apiService.token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = await _apiService.getMe();

      if (!isRider) {
        await _apiService.clearTokens();
        _currentUser = null;
        _riderProfile = null;
        _isAuthenticated = false;
        _isLoading = false;
        _errorMessage = 'Access denied: Only Rider accounts can log in here.';
        notifyListeners();
        return false;
      }

      _riderProfile = await _apiService.getRiderProfile();
      _token = _apiService.token;
      _isAuthenticated = true;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      await _apiService.clearTokens();
      _token = null;
      _currentUser = null;
      _riderProfile = null;
      _isAuthenticated = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authData = await _apiService.login(email, password);
      _token = authData['accessToken'];
      final refresh = authData['refreshToken'];
      await _apiService.setTokens(_token, refresh);

      _currentUser = await _apiService.getMe();

      if (!isRider) {
        await _apiService.clearTokens();
        _token = null;
        _currentUser = null;
        _isAuthenticated = false;
        _errorMessage = 'Access denied: Only Rider accounts can log in here.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _riderProfile = await _apiService.getRiderProfile();
      _isAuthenticated = true;

      _analyticsService.logLogin(
        _currentUser!.id,
        _currentUser!.email,
        _currentUser!.role,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      await _apiService.clearTokens();
      _token = null;
      _currentUser = null;
      _riderProfile = null;
      _isAuthenticated = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> reloadProfile() async {
    if (!_isAuthenticated) return;
    try {
      _riderProfile = await _apiService.getRiderProfile();
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<bool> updateProfileDetails({String? vehicleType, String? vehiclePlateNum}) async {
    if (!_isAuthenticated) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _riderProfile = await _apiService.updateRiderProfile(
        vehicleType: vehicleType,
        vehiclePlateNum: vehiclePlateNum,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _riderProfile = null;
    await _apiService.clearTokens();
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
