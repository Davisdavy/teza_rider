import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  
  FirebaseAnalytics? _analytics;
  bool _isInitialized = false;

  AnalyticsService._internal();

  bool get isInitialized => _isInitialized;

  // Safe initialization that catches missing configuration files
  Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _analytics = FirebaseAnalytics.instance;
      _isInitialized = true;
      debugPrint('[Analytics] Firebase Analytics successfully initialized.');
    } catch (e) {
      _isInitialized = false;
      debugPrint('[Analytics] Firebase initialization failed. Falling back to local logging. Error: $e');
    }
  }

  // Log user login
  Future<void> logLogin(String userId, String email, String role) async {
    _printDebug('user_login', {
      'user_id': userId,
      'email': email,
      'role': role,
    });

    if (!_isInitialized) return;

    try {
      await _analytics?.logLogin(loginMethod: 'email');
      await _analytics?.logEvent(
        name: 'user_login',
        parameters: {
          'user_id': userId,
          'email': email,
          'role': role,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] Failed to send login event: $e');
    }
  }

  // Log duty status changed (Online / Offline)
  Future<void> logDutyStatus(bool online, String riderId, double lat, double lng) async {
    final statusStr = online ? 'online' : 'offline';
    _printDebug('duty_status_changed', {
      'status': statusStr,
      'rider_id': riderId,
      'latitude': lat,
      'longitude': lng,
    });

    if (!_isInitialized) return;

    try {
      await _analytics?.logEvent(
        name: 'duty_status_changed',
        parameters: {
          'status': statusStr,
          'rider_id': riderId,
          'latitude': lat,
          'longitude': lng,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] Failed to send duty_status_changed event: $e');
    }
  }

  // Log delivery offer received
  Future<void> logOfferReceived(
    String offerId,
    String deliveryId,
    double fee,
    String pickupAddress,
    String dropoffAddress,
  ) async {
    _printDebug('offer_received', {
      'offer_id': offerId,
      'delivery_id': deliveryId,
      'fee': fee,
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
    });

    if (!_isInitialized) return;

    try {
      await _analytics?.logEvent(
        name: 'offer_received',
        parameters: {
          'offer_id': offerId,
          'delivery_id': deliveryId,
          'fee': fee,
          'pickup_address': pickupAddress,
          'dropoff_address': dropoffAddress,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] Failed to send offer_received event: $e');
    }
  }

  // Log delivery offer accepted
  Future<void> logOfferAccepted(String offerId, String deliveryId, double fee) async {
    _printDebug('offer_accepted', {
      'offer_id': offerId,
      'delivery_id': deliveryId,
      'fee': fee,
    });

    if (!_isInitialized) return;

    try {
      await _analytics?.logEvent(
        name: 'offer_accepted',
        parameters: {
          'offer_id': offerId,
          'delivery_id': deliveryId,
          'fee': fee,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] Failed to send offer_accepted event: $e');
    }
  }

  // Log delivery offer rejected
  Future<void> logOfferRejected(String offerId, String deliveryId, String reason) async {
    _printDebug('offer_rejected', {
      'offer_id': offerId,
      'delivery_id': deliveryId,
      'reason': reason,
    });

    if (!_isInitialized) return;

    try {
      await _analytics?.logEvent(
        name: 'offer_rejected',
        parameters: {
          'offer_id': offerId,
          'delivery_id': deliveryId,
          'reason': reason,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] Failed to send offer_rejected event: $e');
    }
  }

  // Log active delivery execution status update (stepper progress)
  Future<void> logDeliveryStatus(String deliveryId, String status) async {
    _printDebug('delivery_status_updated', {
      'delivery_id': deliveryId,
      'status': status,
    });

    if (!_isInitialized) return;

    try {
      await _analytics?.logEvent(
        name: 'delivery_status_updated',
        parameters: {
          'delivery_id': deliveryId,
          'status': status,
        },
      );
    } catch (e) {
      debugPrint('[Analytics] Failed to send delivery_status_updated event: $e');
    }
  }

  // Private helper to print events to console
  void _printDebug(String name, Map<String, dynamic> parameters) {
    debugPrint('[Analytics] Event tracked: $name ${parameters.toString()}');
  }
}
