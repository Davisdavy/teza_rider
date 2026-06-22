import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/rider.dart';
import '../models/delivery.dart';
import '../models/offer.dart';
import '../models/notification.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.100.8:8080';
  String? _token;

  void setToken(String? token) {
    _token = token;
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

  // --- Auth Endpoints ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    final response = await http.post(
      url,
      headers: _headers(authenticated: false),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['accessToken'];
      return data;
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<Map<String, dynamic>> refreshToken(String refreshTxt) async {
    final url = Uri.parse('$baseUrl/api/auth/refresh');
    final response = await http.post(
      url,
      headers: _headers(authenticated: false),
      body: jsonEncode({'refreshToken': refreshTxt}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['accessToken'];
      return data;
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<UserAccount> getMe() async {
    final url = Uri.parse('$baseUrl/api/users/me');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      return UserAccount.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  // --- Rider Profile & Location Endpoints ---

  Future<RiderProfile> getRiderProfile() async {
    final url = Uri.parse('$baseUrl/api/rider/profile');
    final response = await http.get(url, headers: _headers());

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

    final response = await http.put(
      url,
      headers: _headers(),
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
    final response = await http.put(
      url,
      headers: _headers(),
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
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => DeliveryOffer.fromJson(e)).toList();
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<Delivery> getDelivery(String deliveryId) async {
    final url = Uri.parse('$baseUrl/api/delivery/$deliveryId');
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      return Delivery.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<DeliveryOffer> respondToOffer(String offerId, bool accepted) async {
    final url = Uri.parse('$baseUrl/api/delivery/offers/$offerId/respond');
    final response = await http.put(
      url,
      headers: _headers(),
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
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => Delivery.fromJson(e)).toList();
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<Delivery> updateDeliveryStatus(String deliveryId, String status, {String? reason}) async {
    final url = Uri.parse('$baseUrl/api/delivery/$deliveryId/status');
    final response = await http.put(
      url,
      headers: _headers(),
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
    final response = await http.get(url, headers: _headers());

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => NotificationModel.fromJson(e)).toList();
    } else {
      throw Exception(_parseError(response));
    }
  }

  Future<void> markNotificationAsRead(String id) async {
    final url = Uri.parse('$baseUrl/api/notifications/$id/read');
    final response = await http.put(url, headers: _headers());

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(_parseError(response));
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    final url = Uri.parse('$baseUrl/api/notifications/read-all');
    final response = await http.put(url, headers: _headers());

    if (response.statusCode != 204 && response.statusCode != 200) {
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
