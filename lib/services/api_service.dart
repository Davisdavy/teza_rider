import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/rider.dart';
import '../models/delivery.dart';
import '../models/offer.dart';
import '../models/notification.dart';
import '../models/rider_stats.dart';

class ApiService {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    
    final host = Uri.base.host;
    if (host.isNotEmpty && host != 'localhost') {
      return '${Uri.base.scheme}://$host:8080';
    }
    
    return 'http://localhost:8080';
  }
  String? _token;
  String? _refreshToken;
  void Function()? onSessionExpired;
  bool _isRefreshing = false;

  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  Future<void> loadPersistedTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('accessToken');
    _refreshToken = prefs.getString('refreshToken');
  }

  Future<void> setTokens(String? accessToken, String? refreshToken) async {
    _token = accessToken;
    _refreshToken = refreshToken;
    final prefs = await SharedPreferences.getInstance();
    if (accessToken != null) {
      await prefs.setString('accessToken', accessToken);
    } else {
      await prefs.remove('accessToken');
    }
    if (refreshToken != null) {
      await prefs.setString('refreshToken', refreshToken);
    } else {
      await prefs.remove('refreshToken');
    }
  }

  Future<void> clearTokens() async {
    _token = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  Map<String, String> _headers({bool authenticated = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authenticated && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<http.Response> _sendRequest(
    String method,
    Uri url, {
    Object? body,
    bool authenticated = true,
  }) async {
    final headers = _headers(authenticated: authenticated);
    switch (method.toUpperCase()) {
      case 'POST':
        return await http.post(url, headers: headers, body: body);
      case 'PUT':
        return await http.put(url, headers: headers, body: body);
      case 'DELETE':
        return await http.delete(url, headers: headers, body: body);
      case 'GET':
      default:
        return await http.get(url, headers: headers);
    }
  }

  Future<http.Response> _sendWithRetry(
    String method,
    Uri url, {
    Object? body,
    bool authenticated = true,
  }) async {
    var response = await _sendRequest(method, url, body: body, authenticated: authenticated);

    if (response.statusCode == 401 && authenticated && _refreshToken != null && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshUrl = Uri.parse('$baseUrl/api/auth/refresh');
        final refreshResponse = await http.post(
          refreshUrl,
          headers: _headers(authenticated: false),
          body: jsonEncode({'refreshToken': _refreshToken}),
        );

        if (refreshResponse.statusCode == 200) {
          final data = jsonDecode(refreshResponse.body);
          final newAccessToken = data['accessToken'];
          final newRefreshToken = data['refreshToken'];
          await setTokens(newAccessToken, newRefreshToken);
          
          // Retry the original request
          response = await _sendRequest(method, url, body: body, authenticated: authenticated);
        } else {
          await clearTokens();
          onSessionExpired?.call();
        }
      } catch (e) {
        await clearTokens();
        onSessionExpired?.call();
      } finally {
        _isRefreshing = false;
      }
    } else if (response.statusCode == 401 && authenticated) {
      await clearTokens();
      onSessionExpired?.call();
    }

    return response;
  }

  // --- Auth Endpoints ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    final response = await _sendWithRetry(
      'POST',
      url,
      body: jsonEncode({'email': email, 'password': password}),
      authenticated: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['accessToken'];
      _refreshToken = data['refreshToken'];
      return data;
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<Map<String, dynamic>> refreshToken(String refreshTxt) async {
    final url = Uri.parse('$baseUrl/api/auth/refresh');
    final response = await _sendWithRetry(
      'POST',
      url,
      body: jsonEncode({'refreshToken': refreshTxt}),
      authenticated: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['accessToken'];
      _refreshToken = data['refreshToken'];
      return data;
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<UserAccount> getMe() async {
    final url = Uri.parse('$baseUrl/api/users/me');
    final response = await _sendWithRetry('GET', url);

    if (response.statusCode == 200) {
      return UserAccount.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  // --- Rider Profile & Location Endpoints ---

  Future<RiderProfile> getRiderProfile() async {
    final url = Uri.parse('$baseUrl/api/rider/profile');
    final response = await _sendWithRetry('GET', url);

    if (response.statusCode == 200) {
      return RiderProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<RiderProfile> updateRiderProfile({
    String? vehicleType,
    String? vehiclePlateNum,
    bool? available,
  }) async {
    final url = Uri.parse('$baseUrl/api/rider/profile');
    final Map<String, dynamic> body = {};
    if (vehicleType != null) body['vehicleType'] = vehicleType;
    if (vehiclePlateNum != null) body['vehiclePlateNum'] = vehiclePlateNum;
    if (available != null) body['available'] = available;

    final response = await _sendWithRetry(
      'PUT',
      url,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return RiderProfile.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<void> updateLocation(double latitude, double longitude) async {
    final url = Uri.parse('$baseUrl/api/rider/location');
    final response = await _sendWithRetry(
      'PUT',
      url,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  // --- Offers & Job Execution ---

  Future<List<DeliveryOffer>> getOffersForRider() async {
    final url = Uri.parse('$baseUrl/api/delivery/rider/offers');
    final response = await _sendWithRetry('GET', url);

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => DeliveryOffer.fromJson(e)).toList();
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<DeliveryOffer> getOfferById(String offerId) async {
    final url = Uri.parse('$baseUrl/api/delivery/offers/$offerId');
    final response = await _sendWithRetry('GET', url);

    if (response.statusCode == 200) {
      return DeliveryOffer.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<Delivery> getDelivery(String deliveryId) async {
    final url = Uri.parse('$baseUrl/api/delivery/$deliveryId');
    final response = await _sendWithRetry('GET', url);

    if (response.statusCode == 200) {
      return Delivery.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<DeliveryOffer> respondToOffer(String offerId, bool accepted) async {
    final url = Uri.parse('$baseUrl/api/delivery/offers/$offerId/respond');
    final response = await _sendWithRetry(
      'PUT',
      url,
      body: jsonEncode({
        'accepted': accepted,
      }),
    );

    if (response.statusCode == 200) {
      return DeliveryOffer.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<List<Delivery>> getDeliveriesForRider() async {
    final url = Uri.parse('$baseUrl/api/delivery/rider');
    final response = await _sendWithRetry('GET', url);

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => Delivery.fromJson(e)).toList();
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<Delivery> updateDeliveryStatus(String deliveryId, String status, {String? reason}) async {
    final url = Uri.parse('$baseUrl/api/delivery/$deliveryId/status');
    final response = await _sendWithRetry(
      'PUT',
      url,
      body: jsonEncode({
        'status': status,
        'reason': reason ?? 'Rider updated status to $status',
      }),
    );

    if (response.statusCode == 200) {
      return Delivery.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  // --- Notifications ---

  Future<List<NotificationModel>> getNotifications() async {
    final url = Uri.parse('$baseUrl/api/notifications');
    final response = await _sendWithRetry('GET', url);

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => NotificationModel.fromJson(e)).toList();
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    final url = Uri.parse('$baseUrl/api/notifications/$id/read');
    final response = await _sendWithRetry('PUT', url);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    final url = Uri.parse('$baseUrl/api/notifications/read-all');
    final response = await _sendWithRetry('PUT', url);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  Future<void> registerDeviceToken(String token, String? deviceId, String? deviceType, String? appVersion) async {
    final url = Uri.parse('$baseUrl/api/notifications/tokens');
    final response = await _sendWithRetry(
      'POST',
      url,
      body: jsonEncode({
        'token': token,
        'deviceId': deviceId,
        'deviceType': deviceType,
        'appVersion': appVersion,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 204 && response.statusCode != 201) {
      throw Exception(_parseError(response));
    }
  }

  Future<void> unregisterDeviceToken(String token) async {
    final url = Uri.parse('$baseUrl/api/notifications/tokens/unregister');
    final response = await _sendWithRetry(
      'POST',
      url,
      body: jsonEncode({
        'token': token,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 204 && response.statusCode != 201) {
      throw Exception(_parseError(response));
    }
  }

  Future<RiderStats> getRiderStats() async {
    final url = Uri.parse('$baseUrl/api/delivery/rider/stats');
    final response = await _sendWithRetry('GET', url);

    if (response.statusCode == 200) {
      return RiderStats.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  // --- Helper to Parse Backend Errors ---

  String _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('message')) {
        return data['message'];
      }
      if (data is Map && data.containsKey('error')) {
        return data['error'];
      }
    } catch (_) {}
    return 'HTTP Error ${response.statusCode}: ${response.reasonPhrase}';
  }
}
