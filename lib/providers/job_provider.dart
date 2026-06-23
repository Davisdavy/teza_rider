import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import '../models/delivery.dart';
import '../models/offer.dart';
import '../models/rider_stats.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../services/location_service.dart';

class JobProvider extends ChangeNotifier {
  final ApiService _apiService;
  final AnalyticsService _analyticsService;

  bool _isOnline = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Coordinates - Default Lower Kabete, Nairobi
  double _latitude = -1.2483;
  double _longitude = 36.7645;
  double _speed = 0.0;

  DeliveryOffer? _activeOffer;
  Delivery? _activeOfferDelivery;
  Delivery? _activeJob;
  RiderStats? _stats;

  final LocationService _locationService = LocationService();
  StreamSubscription<Position>? _positionSubscription;
  Timer? _offersPollTimer;
  Timer? _countdownTimer;
  int _offerCountdown = 0;

  JobProvider(this._apiService, this._analyticsService);

  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get latitude => _latitude;
  double get longitude => _longitude;
  double get speed => _speed;

  DeliveryOffer? get activeOffer => _activeOffer;
  Delivery? get activeOfferDelivery => _activeOfferDelivery;
  Delivery? get activeJob => _activeJob;
  int get offerCountdown => _offerCountdown;
  RiderStats? get stats => _stats;

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
      
      // Load rider statistics
      try {
        _stats = await _apiService.getRiderStats();
      } catch (statsError) {
        debugPrint('Failed to load stats during checkActiveJob: $statsError');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  // Fetch stats independently
  Future<void> fetchRiderStats() async {
    try {
      _stats = await _apiService.getRiderStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch rider stats: $e');
    }
  }

  // Toggle duty status
  Future<bool> toggleOnline(bool online) async {
    if (!online && _activeJob != null) {
      _errorMessage = 'You cannot go offline during an active delivery.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    if (online) {
      final hasPermission = await _locationService.handleLocationPermission();
      if (!hasPermission) {
        _isLoading = false;
        _errorMessage = 'Location permission is required to go online.';
        notifyListeners();
        return false;
      }

      try {
        final pos = await _locationService.getCurrentPosition();
        if (pos != null) {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _speed = pos.speed;
        }
      } catch (e) {
        debugPrint('Failed to retrieve initial position: $e');
      }
    }

    try {
      // Update profile available status in backend
      final profile = await _apiService.updateRiderProfile(available: online);
      _isOnline = online;

      // Log duty status change
      _analyticsService.logDutyStatus(online, profile.id, _latitude, _longitude);

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
    _stopLocationUpdates();
    
    _positionSubscription = _locationService.getPositionStream().listen(
      (position) async {
        if (!_isOnline) return;
        _latitude = position.latitude;
        _longitude = position.longitude;
        _speed = position.speed;
        notifyListeners();

        try {
          await _apiService.updateLocation(_latitude, _longitude);
        } catch (e) {
          debugPrint('Failed to update streaming location to API: $e');
        }
      },
      onError: (e) {
        debugPrint('Location stream error: $e');
      },
    );
  }

  void _stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
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
          
          // Calculate remaining seconds
          final diff = pendingOffer.expiresAt.difference(DateTime.now()).inSeconds;
          if (diff > 0) {
            // Fetch delivery details
            final delivery = await _apiService.getDelivery(pendingOffer.deliveryId);
            
            _activeOffer = pendingOffer;
            _activeOfferDelivery = delivery;
            _offerCountdown = diff;

            // Log offer received
            _analyticsService.logOfferReceived(
              pendingOffer.id,
              pendingOffer.deliveryId,
              delivery.deliveryFee,
              delivery.pickupAddress,
              delivery.dropoffAddress,
            );

            // Play sound notification and vibrate on receive
            try {
              FlutterRingtonePlayer().play(
                fromAsset: 'assets/sounds/offer_alert_bell.mp3',
                looping: false,
                volume: 1.0,
                asAlarm: false,
              );
              HapticFeedback.vibrate();
            } catch (e) {
              debugPrint('Failed to play custom ringtone/vibrate: $e');
            }

            _startCountdown();
            notifyListeners();
          }
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
        // Pulse vibrate every 2 seconds during active offer request
        if (_offerCountdown % 2 == 0) {
          try {
            HapticFeedback.vibrate();
          } catch (e) {
            debugPrint('Failed to vibrate: $e');
          }
        }
        notifyListeners();
      } else {
        // Expired
        try {
          FlutterRingtonePlayer().stop();
        } catch (e) {
          debugPrint('Failed to stop sound: $e');
        }
        if (_activeOffer != null) {
          // Log offer timeout rejection
          _analyticsService.logOfferRejected(
            _activeOffer!.id,
            _activeOffer!.deliveryId,
            'timeout',
          );
        }
        _activeOffer = null;
        _activeOfferDelivery = null;
        _stopCountdown();
        fetchRiderStats(); // Refresh stats on timeout
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
    final deliveryId = _activeOffer!.deliveryId;
    final fee = _activeOfferDelivery?.deliveryFee ?? 0.0;
    _stopCountdown();
    try {
      FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('Failed to stop sound: $e');
    }

    try {
      await _apiService.respondToOffer(offerId, true);
      
      // Log offer accepted
      _analyticsService.logOfferAccepted(offerId, deliveryId, fee);
      
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
    final deliveryId = _activeOffer!.deliveryId;
    _activeOffer = null;
    _activeOfferDelivery = null;
    _stopCountdown();
    try {
      FlutterRingtonePlayer().stop();
    } catch (e) {
      debugPrint('Failed to stop sound: $e');
    }

    try {
      await _apiService.respondToOffer(offerId, false);

      // Log offer declined
      _analyticsService.logOfferRejected(offerId, deliveryId, 'manual');

      await fetchRiderStats(); // Refresh stats on decline

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

      // Log delivery execution progress step
      _analyticsService.logDeliveryStatus(_activeJob!.id, newStatus);

      if (newStatus == 'DELIVERED' || newStatus == 'CANCELLED') {
        _activeJob = null;
      } else {
        _activeJob = updated;
      }

      await fetchRiderStats(); // Refresh stats on status update (e.g. delivery completion)

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
