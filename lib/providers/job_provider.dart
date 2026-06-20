import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/delivery.dart';
import '../models/offer.dart';
import '../services/api_service.dart';

class JobProvider extends ChangeNotifier {
  final ApiService _apiService;

  bool _isOnline = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Coordinates - Default Lower Kabete, Nairobi
  double _latitude = -1.2483;
  double _longitude = 36.7645;

  DeliveryOffer? _activeOffer;
  Delivery? _activeOfferDelivery;
  Delivery? _activeJob;

  Timer? _locationTimer;
  Timer? _offersPollTimer;
  Timer? _countdownTimer;
  int _offerCountdown = 0;

  final Random _random = Random();

  JobProvider(this._apiService);

  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get latitude => _latitude;
  double get longitude => _longitude;

  DeliveryOffer? get activeOffer => _activeOffer;
  Delivery? get activeOfferDelivery => _activeOfferDelivery;
  Delivery? get activeJob => _activeJob;
  int get offerCountdown => _offerCountdown;

  // Initialize and check if there's any active job already assigned
  Future<void> checkActiveJob() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deliveries = await _apiService.getDeliveriesForRider();
      final active = deliveries.firstWhere(
        (d) => d.status != 'DELIVERED' && d.status != 'CANCELLED',
        orElse: () => Delivery(
          id: '',
          pickupAddress: '',
          pickupLatitude: 0,
          pickupLongitude: 0,
          dropoffAddress: '',
          dropoffLatitude: 0,
          dropoffLongitude: 0,
          status: '',
          deliveryFee: 0,
        ),
      );

      if (active.id.isNotEmpty) {
        _activeJob = active;
        // If there's an active job, rider should not be getting new offers
        // but they should be online (or status matched)
        _isOnline = true;
        _startLocationUpdates();
      } else {
        _activeJob = null;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // Toggle duty status
  Future<bool> toggleOnline(bool online) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Update profile available status in backend
      await _apiService.updateRiderProfile(available: online);
      _isOnline = online;

      if (_isOnline) {
        // Send initial location
        await _apiService.updateLocation(_latitude, _longitude);
        _startLocationUpdates();
        _startOffersPolling();
      } else {
        _stopLocationUpdates();
        _stopOffersPolling();
        _activeOffer = null;
        _activeOfferDelivery = null;
        _stopCountdown();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Location Updates Loop
  void _startLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!_isOnline) return;

      // Simulate a small movement/drift (GPS simulation)
      _latitude += (_random.nextDouble() - 0.5) * 0.00015;
      _longitude += (_random.nextDouble() - 0.5) * 0.00015;

      try {
        await _apiService.updateLocation(_latitude, _longitude);
        notifyListeners();
      } catch (e) {
        debugPrint('Failed to update location: $e');
      }
    });
  }

  void _stopLocationUpdates() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // Offers Polling Loop
  void _startOffersPolling() {
    _offersPollTimer?.cancel();
    _offersPollTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isOnline || _activeJob != null || _activeOffer != null) return;

      try {
        final offers = await _apiService.getOffersForRider();
        if (offers.isNotEmpty) {
          final pendingOffer = offers.first;
          // Fetch delivery details
          final delivery = await _apiService.getDelivery(pendingOffer.deliveryId);
          
          _activeOffer = pendingOffer;
          _activeOfferDelivery = delivery;

          // Calculate remaining seconds
          final diff = pendingOffer.expiresAt.difference(DateTime.now()).inSeconds;
          _offerCountdown = diff > 0 ? diff : 0;

          _startCountdown();
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Failed to poll offers: $e');
      }
    });
  }

  void _stopOffersPolling() {
    _offersPollTimer?.cancel();
    _offersPollTimer = null;
  }

  // Countdown timer for pending offer
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_offerCountdown > 0) {
        _offerCountdown--;
        notifyListeners();
      } else {
        // Expired
        _activeOffer = null;
        _activeOfferDelivery = null;
        _stopCountdown();
        notifyListeners();
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  // Accept offer
  Future<bool> acceptOffer() async {
    if (_activeOffer == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final offerId = _activeOffer!.id;
    _stopCountdown();

    try {
      await _apiService.respondToOffer(offerId, true);
      
      // Successfully accepted. Check active job to load it
      _activeOffer = null;
      _activeOfferDelivery = null;
      
      await checkActiveJob();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Decline offer
  Future<bool> declineOffer() async {
    if (_activeOffer == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final offerId = _activeOffer!.id;
    _activeOffer = null;
    _activeOfferDelivery = null;
    _stopCountdown();

    try {
      await _apiService.respondToOffer(offerId, false);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Status transitions
  Future<bool> updateJobStatus(String newStatus) async {
    if (_activeJob == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _apiService.updateDeliveryStatus(
        _activeJob!.id,
        newStatus,
      );

      if (newStatus == 'DELIVERED' || newStatus == 'CANCELLED') {
        _activeJob = null;
      } else {
        _activeJob = updated;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    _stopOffersPolling();
    _stopCountdown();
    super.dispose();
  }
}
