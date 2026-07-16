import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/delivery.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final MapController _mapController = MapController();
  bool _isLightMap = false;

  // Route points and map state
  bool _isMapExpanded = false;
  List<LatLng> _tripRoute = [];
  List<LatLng> _activeLegRoute = [];
  LatLng? _lastRiderLatLng;
  String? _lastFetchedKey;
  bool _isFetchingRoute = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onToggleDuty(bool val) async {
    final jobProvider = Provider.of<JobProvider>(context, listen: false);
    final success = await jobProvider.toggleOnline(val);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(jobProvider.errorMessage ?? 'Failed to update duty status'),
          backgroundColor: const Color(0xFFFF5252),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final jobProvider = Provider.of<JobProvider>(context);

    final rider = authProvider.riderProfile;
    final isOnboarded = rider?.onboardingStatus == 'APPROVED';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151622),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              'TEZA RIDER',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          // Profile Action
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white70),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Status Bar (Duty Control)
            _buildDutyControlBar(jobProvider, isOnboarded, rider?.onboardingStatus ?? 'PENDING'),

            // Error Message Banner
            if (jobProvider.errorMessage != null)
              _buildErrorBanner(jobProvider),

            // Main Body Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildMainContent(jobProvider, isOnboarded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyControlBar(JobProvider job, bool approved, String onboardingStatus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: const Color(0xFF151622),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Pulsing Online/Offline Dot
              if (job.isOnline && approved)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF00E676).withOpacity(_pulseController.value),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E676),
                            blurRadius: 4 + 8 * _pulseController.value,
                          )
                        ],
                      ),
                    );
                  },
                )
              else
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFF5252),
                  ),
                ),
              const SizedBox(width: 10),
              Text(
                !approved
                    ? 'BLOCKED ($onboardingStatus)'
                    : (job.isOnline ? 'Availability - ONLINE' : 'Availability - OFFLINE'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Switch(
            value: job.isOnline,
            onChanged: !approved
                ? null
                : (val) {
                    if (job.activeJob != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('You cannot go offline during an active delivery!'),
                          backgroundColor: Color(0xFFFF5252),
                        ),
                      );
                      return;
                    }
                    _onToggleDuty(val);
                  },
            activeColor: const Color(0xFF00E676),
            activeTrackColor: const Color(0xFF00E676).withOpacity(0.2),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(JobProvider job) {
    return Container(
      color: const Color(0xFFFF5252).withOpacity(0.12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              job.errorMessage!,
              style: GoogleFonts.inter(color: const Color(0xFFFF8A8A), fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 16),
            onPressed: () => job.clearError(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(JobProvider job, bool approved) {
    if (job.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00E676),
        ),
      );
    }

    if (!approved) {
      return _buildPendingApprovalView();
    }

    if (!job.isOnline) {
      return _buildOfflineStandbyView();
    }

    // If online, we check offers and active jobs
    if (job.activeOffer != null) {
      return _buildOfferDetailView(job);
    }

    if (job.activeJob != null) {
      return _buildActiveJobView(job);
    }

    // Clear routes if no active job
    _tripRoute.clear();
    _activeLegRoute.clear();
    _lastFetchedKey = null;
    _lastRiderLatLng = null;

    return _buildScanningRadarView(job);
  }

  // --- OSRM Routing Helpers ---

  void _checkAndFetchRoute(LatLng rider, LatLng pickup, LatLng dropoff, String deliveryId, String status) async {
    final isGoingToPickup = status == 'ASSIGNED' || status == 'ARRIVED';
    final target = isGoingToPickup ? pickup : dropoff;
    
    final riderMovedSignificantly = _lastRiderLatLng == null ||
        (rider.latitude - _lastRiderLatLng!.latitude).abs() > 0.0005 ||
        (rider.longitude - _lastRiderLatLng!.longitude).abs() > 0.0005;

    final key = '${deliveryId}_${status}';
    if (key != _lastFetchedKey || riderMovedSignificantly) {
      if (_isFetchingRoute) return;
      _isFetchingRoute = true;
      _lastRiderLatLng = rider;
      _lastFetchedKey = key;
      
      try {
        List<LatLng> trip = _tripRoute;
        if (trip.isEmpty || trip.first != pickup || trip.last != dropoff) {
          trip = await _getOSRMRoute(pickup, dropoff);
        }
        
        final leg = await _getOSRMRoute(rider, target);
        
        if (mounted) {
          setState(() {
            _tripRoute = trip;
            _activeLegRoute = leg;
          });
        }
      } catch (e) {
        debugPrint('Error updating routes: $e');
      } finally {
        _isFetchingRoute = false;
      }
    }
  }

  Future<List<LatLng>> _getOSRMRoute(LatLng start, LatLng end) async {
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          return coordinates.map((coord) => LatLng(coord[1] as double, coord[0] as double)).toList();
        }
      }
    } catch (e) {
      debugPrint('OSRM routing error: $e');
    }
    return [start, end];
  }

  int _findClosestPointIndex(LatLng point, List<LatLng> points) {
    if (points.isEmpty) return -1;
    int closestIndex = 0;
    double minDistance = double.maxFinite;
    
    for (int i = 0; i < points.length; i++) {
      final dLat = points[i].latitude - point.latitude;
      final dLng = points[i].longitude - point.longitude;
      final dist = dLat * dLat + dLng * dLng;
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }
    return closestIndex;
  }

  // View shown when rider profile is PENDING onboarding approval
  Widget _buildPendingApprovalView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB300).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_empty,
              color: Color(0xFFFFB300),
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Account Under Review',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Your profile onboarding progress is currently PENDING. Dispatch systems require administrator approval before you are allowed to declare online duty status or execute deliveries.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.45),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // View shown when approved but offline
  Widget _buildOfflineStandbyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              color: Colors.white.withOpacity(0.12),
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'You are Offline',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toggle the switch above to go online and receive jobs.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  // Scanning radar view when online and standby
  Widget _buildScanningRadarView(JobProvider job) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const RadarScanner(),
            const SizedBox(height: 32),
            Text(
              'Scanning for Delivery Offers',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep this screen active to receive local dispatches...',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 48),
            
            // GPS Coordinates Panel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF151622),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.gps_fixed, color: Color(0xFF00E676), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'GPS Tracking Active',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    job.currentArea ?? 'Lat: ${job.latitude.toStringAsFixed(6)}   •   Lng: ${job.longitude.toStringAsFixed(6)}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: job.currentArea != null ? 14 : 15,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF00E676),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.currentArea != null
                        ? 'Current Location (Nearest Area/Landmark)'
                        : 'Coordinates are updating in real-time.',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card view for responding to active delivery offer
  Widget _buildOfferDetailView(JobProvider job) {
    final delivery = job.activeOfferDelivery;
    if (delivery == null) return const SizedBox();

    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151622),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF00E676).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Alert Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.flash_on, color: Color(0xFFFFB300), size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'NEW JOB OFFER',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  // Time Countdown Indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5252).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: Color(0xFFFF5252), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${job.offerCountdown}s',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF8A8A),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 28),
  
              // Locations
              _buildLocationStep(
                icon: Icons.circle,
                iconColor: const Color(0xFF00E676),
                title: 'PICKUP',
                address: delivery.pickupAddress,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 11, top: 4, bottom: 4),
                child: SizedBox(
                  height: 20,
                  child: VerticalDivider(color: Colors.white10, width: 2, thickness: 1.5),
                ),
              ),
              _buildLocationStep(
                icon: Icons.location_on,
                iconColor: const Color(0xFFFF5252),
                title: 'DROPOFF',
                address: delivery.dropoffAddress,
              ),
  
              const SizedBox(height: 24),
  
              // Estimated Delivery Fee
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payout Fee',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'KSh ${delivery.deliveryFee.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00E676),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
  
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => job.declineOffer(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withOpacity(0.12)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Decline',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => job.acceptOffer(),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF00E676),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Accept Job',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationStep({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withOpacity(0.4),
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  // OTP Verification Dialog for Proof of Delivery
  void _showOtpVerificationDialog(BuildContext context, JobProvider job) {
    final otpController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return PopScope(
              canPop: false,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF12131F),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withOpacity(0.08),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header icon
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF00E676).withOpacity(0.12),
                                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4), width: 1.5),
                              ),
                              child: const Icon(Icons.verified_rounded, color: Color(0xFF00E676), size: 30),
                            ),
                            const SizedBox(height: 20),
    
                            // Title
                            Text(
                              'Proof of Delivery',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
    
                            // Subtitle
                            Text(
                              'Ask the customer for their 6-digit verification code and enter it below to confirm delivery.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 28),
    
                            // OTP Input Field
                            TextFormField(
                              controller: otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 12,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '------',
                                hintStyle: GoogleFonts.outfit(
                                  color: Colors.white12,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 12,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF1E1F2E),
                                contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.white12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.white12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter the verification code';
                                }
                                if (val.trim().length != 6) {
                                  return 'Code must be exactly 6 digits';
                                }
                                if (!RegExp(r'^\d{6}$').hasMatch(val.trim())) {
                                  return 'Code must contain digits only';
                                }
                                return null;
                              },
                              onChanged: (val) {
                                if (dialogError != null) {
                                  setDialogState(() => dialogError = null);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
    
                            // Hint
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 13),
                                const SizedBox(width: 6),
                                Text(
                                  'The customer received this code via SMS',
                                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
                                ),
                              ],
                            ),
                            
                            if (dialogError != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5252).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252), size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        dialogError!,
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFFF5252),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 28),
    
                            // Confirm Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        if (!formKey.currentState!.validate()) return;
                                        setDialogState(() {
                                          isSubmitting = true;
                                          dialogError = null;
                                        });
    
                                        final code = otpController.text.trim();
                                        final success = await job.updateJobStatus('DELIVERED', otp: code);
                                        
                                        if (success) {
                                          if (dialogContext.mounted) {
                                            Navigator.of(dialogContext).pop();
                                          }
                                        } else {
                                          if (dialogContext.mounted) {
                                            setDialogState(() {
                                              isSubmitting = false;
                                              dialogError = job.errorMessage ?? 'Invalid verification code. Please try again.';
                                            });
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  backgroundColor: const Color(0xFF00E676),
                                  disabledBackgroundColor: const Color(0xFF00E676).withOpacity(0.4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Verify & Complete Delivery',
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
    
                            // Cancel Button
                            TextButton(
                              onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Layout when actively executing a job (assigned delivery)
  Widget _buildActiveJobView(JobProvider job) {

    final delivery = job.activeJob!;
    
    // Determine target step and next action text
    String nextStatus = '';
    String actionLabel = '';
    int currentStep = 0;

    switch (delivery.status) {
      case 'ASSIGNED':
        nextStatus = 'ARRIVED';
        actionLabel = 'I Have Arrived at Pickup';
        currentStep = 0;
        break;
      case 'ARRIVED':
        nextStatus = 'PICKED_UP';
        actionLabel = 'I Have Picked Up Package';
        currentStep = 1;
        break;
      case 'PICKED_UP':
        nextStatus = 'IN_TRANSIT';
        actionLabel = 'Start Transit to Destination';
        currentStep = 2;
        break;
      case 'IN_TRANSIT':
        nextStatus = 'DELIVERED';
        actionLabel = 'Confirm Delivery Completed';
        currentStep = 3;
        break;
    }

    // Dynamic ETA calculations
    final isGoingToPickup = delivery.status == 'ASSIGNED' || delivery.status == 'ARRIVED';
    final targetLat = isGoingToPickup ? delivery.pickupLatitude : delivery.dropoffLatitude;
    final targetLng = isGoingToPickup ? delivery.pickupLongitude : delivery.dropoffLongitude;

    double distanceKm = 0.0;
    if (_activeLegRoute.isNotEmpty) {
      for (int i = 0; i < _activeLegRoute.length - 1; i++) {
        distanceKm += Geolocator.distanceBetween(
          _activeLegRoute[i].latitude,
          _activeLegRoute[i].longitude,
          _activeLegRoute[i + 1].latitude,
          _activeLegRoute[i + 1].longitude,
        ) / 1000.0;
      }
    }

    if (distanceKm == 0.0) {
      distanceKm = Geolocator.distanceBetween(
        job.latitude,
        job.longitude,
        targetLat,
        targetLng,
      ) / 1000.0;
    }

    double speedKmH = job.speed * 3.6;
    if (speedKmH < 10.0) {
      speedKmH = 30.0; // default average speed in traffic
    } else if (speedKmH > 80.0) {
      speedKmH = 80.0; // cap max speed
    }

    final timeMinutes = (distanceKm / speedKmH * 60).round();
    final displayTime = timeMinutes < 1 && distanceKm > 0.05 ? 1 : timeMinutes;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Active job header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF00E676).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_rounded, color: Color(0xFF00E676), size: 18),
                const SizedBox(width: 8),
                Text(
                  isGoingToPickup
                      ? 'Estimated Pickup Time: ${displayTime}Min'
                      : 'Estimated Delivery Time: ${displayTime}Min',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00E676),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildMapSection(job, delivery),

          // Details Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF151622),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Stepper progress indicator
                _buildJobStepper(currentStep),
                const Divider(color: Colors.white10, height: 32),

                // Pickup details
                _buildLocationStep(
                  icon: Icons.circle,
                  iconColor: const Color(0xFF00E676),
                  title: 'PICKUP FROM',
                  address: delivery.pickupAddress,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 11, top: 4, bottom: 4),
                  child: SizedBox(
                    height: 20,
                    child: VerticalDivider(color: Colors.white10, width: 2),
                  ),
                ),
                // Dropoff details
                _buildLocationStep(
                  icon: Icons.location_on,
                  iconColor: const Color(0xFFFF5252),
                  title: 'DELIVER TO',
                  address: delivery.dropoffAddress,
                ),
                
                const Divider(color: Colors.white10, height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Payout',
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                    ),
                    Text(
                      'KSh ${delivery.deliveryFee.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00E676),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Primary Step Button
          ElevatedButton(
            onPressed: () {
              if (nextStatus == 'DELIVERED') {
                _showOtpVerificationDialog(context, job);
              } else {
                job.updateJobStatus(nextStatus);
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: const Color(0xFF00E676),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF00E676).withOpacity(0.2),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),
          // Cancel Delivery Button (Merchant or Admin can trigger this, but we allow support request)
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF151622),
                  title: Text(
                    'Cancel Active Job?',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    'To cancel this job, please contact system support or declare cancellation. This will release the delivery request back to search.',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Go Back'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF5252)),
                      child: const Text('Cancel Job'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        job.updateJobStatus('CANCELLED');
                      },
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.cancel_outlined, color: Colors.white30, size: 16),
            label: Text(
              'Cancel Delivery / Contact Dispatcher',
              style: GoogleFonts.inter(color: Colors.white30, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Multi-step visual progress bar
  Widget _buildJobStepper(int currentStep) {
    final stepLabels = ['Assigned', 'Arrived', 'Picked Up', 'In Transit', 'Delivered'];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(stepLabels.length, (index) {
        final isCompleted = index < currentStep;
        final isActive = index == currentStep;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 2.5,
                      color: index == 0
                          ? Colors.transparent
                          : (isCompleted || isActive ? const Color(0xFF00E676) : Colors.white10),
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? const Color(0xFF00E676)
                          : (isCompleted ? const Color(0xFF00BFA5).withOpacity(0.3) : const Color(0xFF1F2033)),
                      border: Border.all(
                        color: isActive || isCompleted
                            ? const Color(0xFF00E676)
                            : Colors.white24,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, size: 10, color: Colors.white)
                          : (isActive
                              ? Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                )
                              : const SizedBox()),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 2.5,
                      color: index == stepLabels.length - 1
                          ? Colors.transparent
                          : (isCompleted ? const Color(0xFF00E676) : Colors.white10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                stepLabels[index],
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 8.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? const Color(0xFF00E676)
                      : (isCompleted ? Colors.white70 : Colors.white24),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _recenterMap(double lat, double lng, {double zoom = 15.0}) {
    try {
      _mapController.move(LatLng(lat, lng), zoom);
    } catch (e) {
      debugPrint('Error recentering map: $e');
    }
  }

  Widget _buildMapSection(JobProvider job, Delivery delivery) {
    // Current target coords based on job status
    final isGoingToPickup = delivery.status == 'ASSIGNED' || delivery.status == 'ARRIVED';
    final targetLat = isGoingToPickup ? delivery.pickupLatitude : delivery.dropoffLatitude;
    final targetLng = isGoingToPickup ? delivery.pickupLongitude : delivery.dropoffLongitude;
    final targetLabel = isGoingToPickup ? 'Pickup' : 'Dropoff';

    final riderLatLng = LatLng(job.latitude, job.longitude);
    final pickupLatLng = LatLng(delivery.pickupLatitude, delivery.pickupLongitude);
    final dropoffLatLng = LatLng(delivery.dropoffLatitude, delivery.dropoffLongitude);
    final targetLatLng = LatLng(targetLat, targetLng);

    // Schedule fetching road route points safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndFetchRoute(riderLatLng, pickupLatLng, dropoffLatLng, delivery.id, delivery.status);
    });

    // Tile URLs
    final darkTileUrl = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
    final lightTileUrl = 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    // Premium styling for polyline (route)
    // Make paths bright and easy to see during the day
    final routeColor = _isLightMap ? const Color(0xFF00796B) : const Color(0xFF00E676);
    final totalPathColor = _isLightMap ? Colors.black38 : Colors.white24;

    final mapHeight = _isMapExpanded ? 480.0 : 280.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: mapHeight,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF151622),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: riderLatLng,
                initialZoom: 14.5,
                maxZoom: 18.0,
                minZoom: 10.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: _isLightMap ? lightTileUrl : darkTileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.wafula.teza.rider',
                ),
                PolylineLayer(
                  polylines: [
                    if (delivery.status == 'PICKED_UP' || delivery.status == 'IN_TRANSIT') ...[
                      // Traversed portion of trip (greyed out)
                      ...() {
                        final closestIdx = _findClosestPointIndex(riderLatLng, _tripRoute);
                        if (closestIdx > 0 && _tripRoute.isNotEmpty) {
                          return [
                            Polyline(
                              points: _tripRoute.sublist(0, closestIdx + 1),
                              color: _isLightMap ? Colors.black26 : Colors.white24,
                              strokeWidth: 4.0,
                            )
                          ];
                        }
                        return const <Polyline>[];
                      }(),
                      // Remaining portion of trip (active leg)
                      () {
                        final closestIdx = _findClosestPointIndex(riderLatLng, _tripRoute);
                        if (closestIdx != -1 && _tripRoute.isNotEmpty) {
                          return Polyline(
                            points: _tripRoute.sublist(closestIdx),
                            color: routeColor,
                            strokeWidth: 4.5,
                          );
                        }
                        return Polyline(
                          points: _tripRoute.isNotEmpty ? _tripRoute : [pickupLatLng, dropoffLatLng],
                          color: routeColor,
                          strokeWidth: 4.5,
                        );
                      }(),
                    ] else ...[
                      // Entire journey (Pickup to Dropoff) - dashed/thin
                      Polyline(
                        points: _tripRoute.isNotEmpty ? _tripRoute : [pickupLatLng, dropoffLatLng],
                        color: totalPathColor,
                        strokeWidth: 2.0,
                        pattern: StrokePattern.dashed(segments: [8, 4]),
                      ),
                      // Active leg (Rider to next Target) - bright and highly visible
                      Polyline(
                        points: _activeLegRoute.isNotEmpty ? _activeLegRoute : [riderLatLng, targetLatLng],
                        color: routeColor,
                        strokeWidth: 4.5,
                      ),
                    ],
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Pickup Marker
                    Marker(
                      point: pickupLatLng,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF151622).withOpacity(0.9),
                          border: Border.all(color: const Color(0xFF00E676), width: 2),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFF00E676),
                          size: 20,
                        ),
                      ),
                    ),
                    // Dropoff Marker
                    Marker(
                      point: dropoffLatLng,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF151622).withOpacity(0.9),
                          border: Border.all(color: const Color(0xFFFF5252), width: 2),
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFFF5252),
                          size: 20,
                        ),
                      ),
                    ),
                    // Rider (Current Position) Marker - Pulsing layout
                    Marker(
                      point: riderLatLng,
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow circle
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00BFA5).withOpacity(0.3),
                            ),
                          ),
                          // Inner border and solid dot
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF00BFA5),
                                ),
                              ),
                            ),
                          ),
                          // Small direction pointer pointing towards target
                          Positioned(
                            top: 4,
                            child: Icon(
                              Icons.navigation,
                              size: 10,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Top-left Style Toggle overlay
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF151622).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: IconButton(
                  icon: Icon(
                    _isLightMap ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: _isLightMap ? Colors.white : const Color(0xFFFFB300),
                    size: 18,
                  ),
                  tooltip: _isLightMap ? 'Switch to Dark Map' : 'Switch to Light Map (Day)',
                  onPressed: () {
                    setState(() {
                      _isLightMap = !_isLightMap;
                    });
                  },
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),

            // Right controls overlay
            Positioned(
              bottom: 12,
              right: 12,
              child: Column(
                children: [
                  // Expand / Collapse Map
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151622).withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isMapExpanded ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: const Color(0xFF00E676),
                        size: 18,
                      ),
                      tooltip: _isMapExpanded ? 'Collapse Map' : 'Expand Map',
                      onPressed: () {
                        setState(() {
                          _isMapExpanded = !_isMapExpanded;
                        });
                      },
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  // Recenter on Target
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151622).withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: IconButton(
                      icon: Icon(
                        isGoingToPickup ? Icons.storefront_outlined : Icons.flag_outlined,
                        color: const Color(0xFF00E676),
                        size: 18,
                      ),
                      tooltip: 'Center on $targetLabel',
                      onPressed: () => _recenterMap(targetLat, targetLng),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  // Recenter on Me
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF151622).withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.my_location,
                        color: Color(0xFF00BFA5),
                        size: 18,
                      ),
                      tooltip: 'Center on Me',
                      onPressed: () => _recenterMap(job.latitude, job.longitude),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RadarScanner extends StatefulWidget {
  const RadarScanner({super.key});

  @override
  State<RadarScanner> createState() => _RadarScannerState();
}

class _RadarScannerState extends State<RadarScanner> with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple 1
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              final progress = _rippleController.value;
              return Transform.scale(
                scale: 1.0 + (progress * 1.5),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E676).withOpacity(0.12 * (1.0 - progress)),
                    border: Border.all(
                      color: const Color(0xFF00E676).withOpacity(0.3 * (1.0 - progress)),
                      width: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),
          // Ripple 2 (staggered by 0.5)
          AnimatedBuilder(
            animation: _rippleController,
            builder: (context, child) {
              final progress = (_rippleController.value + 0.5) % 1.0;
              return Transform.scale(
                scale: 1.0 + (progress * 1.5),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00E676).withOpacity(0.12 * (1.0 - progress)),
                    border: Border.all(
                      color: const Color(0xFF00E676).withOpacity(0.3 * (1.0 - progress)),
                      width: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),
          // Sweep Rotation
          RotationTransition(
            turns: _rotationController,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    const Color(0xFF00E676).withOpacity(0.12),
                    const Color(0xFF00E676).withOpacity(0.0),
                  ],
                  stops: const [0.25, 1.0],
                ),
              ),
            ),
          ),
          // Central Radar Base
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF151622),
              border: Border.all(
                color: const Color(0xFF00E676).withOpacity(0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E676).withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: const Icon(
              Icons.radar,
              color: Color(0xFF00E676),
              size: 36,
            ),
          ),
        ],
      ),
    );
  }
}
