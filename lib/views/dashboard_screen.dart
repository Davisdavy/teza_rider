import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
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
                    : (job.isOnline ? 'ON DUTY - ONLINE' : 'OFF DUTY - OFFLINE'),
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
            onChanged: !approved ? null : _onToggleDuty,
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

    return _buildScanningRadarView(job);
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
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toggle the switch above to go online and receive jobs.',
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
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 48),
          
          // Simulated Coordinates Panel
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
                    const Icon(Icons.gps_fixed, color: Color(0xFF00BFA5), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Simulated GPS (Lower Kabete)',
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
                  'Lat: ${job.latitude.toStringAsFixed(6)}   •   Lng: ${job.longitude.toStringAsFixed(6)}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00E676),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Slight random drifts are applied to simulate movement.',
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
    );
  }

  // Card view for responding to active delivery offer
  Widget _buildOfferDetailView(JobProvider job) {
    final delivery = job.activeOfferDelivery;
    if (delivery == null) return const SizedBox();

    return Center(
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
                    'KSh ${delivery.deliveryFee.toStringAsFixed(2)}',
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
                const Icon(Icons.directions_run, color: Color(0xFF00E676), size: 18),
                const SizedBox(width: 8),
                Text(
                  'ACTIVE EXECUTION JOB',
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
                      'KSh ${delivery.deliveryFee.toStringAsFixed(2)}',
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
            onPressed: () => job.updateJobStatus(nextStatus),
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
