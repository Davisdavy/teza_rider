import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/job_provider.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _plateController;
  String _selectedVehicleType = 'MOTORCYCLE';
  bool _isInit = true;

  final List<String> _vehicleTypes = ['MOTORCYCLE', 'BICYCLE', 'CAR'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final profile = Provider.of<AuthProvider>(context, listen: false).riderProfile;
      _plateController = TextEditingController(text: profile?.vehiclePlateNum ?? '');
      
      final type = profile?.vehicleType ?? 'MOTORCYCLE';
      if (_vehicleTypes.contains(type.toUpperCase())) {
        _selectedVehicleType = type.toUpperCase();
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.updateProfileDetails(
        vehicleType: _selectedVehicleType,
        vehiclePlateNum: _plateController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Profile updated successfully!' : (authProvider.errorMessage ?? 'Update failed'),
            ),
            backgroundColor: success ? const Color(0xFF00E676) : const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  void _handleLogout() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final jobProvider = Provider.of<JobProvider>(context, listen: false);
    
    // Stop all tracking loops
    jobProvider.toggleOnline(false);
    authProvider.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final rider = authProvider.riderProfile;
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0E15),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151622),
        title: Text(
          'Rider Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Account Card
              _buildAccountCard(user?.email ?? 'Unknown User', rider?.onboardingStatus ?? 'PENDING'),
              const SizedBox(height: 24),

              // Rating Banner
              _buildRatingCard(),
              const SizedBox(height: 24),

              // Vehicle Editing Form
              Text(
                'VEHICLE DETAILS',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white30,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              
              // Vehicle Type Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF151622),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedVehicleType,
                    dropdownColor: const Color(0xFF151622),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                    items: _vehicleTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(
                          type,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedVehicleType = val;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Plate Number
              TextFormField(
                controller: _plateController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  hintText: 'e.g. KAA 123A',
                  labelText: 'Vehicle Plate Number',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter plate number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Action Buttons
              ElevatedButton(
                onPressed: authProvider.isLoading ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF00E676),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: authProvider.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Save Profile Changes',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              
              const SizedBox(height: 48),

              // Sign Out Button
              OutlinedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout, color: Color(0xFFFF5252), size: 18),
                label: Text(
                  'Log Out Account',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF5252),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFFFF5252)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(String email, String onboardingStatus) {
    Color statusColor = const Color(0xFFFFB300); // Pending
    if (onboardingStatus == 'APPROVED') {
      statusColor = const Color(0xFF00E676);
    } else if (onboardingStatus == 'REJECTED') {
      statusColor = const Color(0xFFFF5252);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151622),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: statusColor.withOpacity(0.12),
            child: Icon(Icons.two_wheeler, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'STATUS: ',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white38,
                      ),
                    ),
                    Text(
                      onboardingStatus,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161C24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD600).withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFFD600), size: 22),
              const SizedBox(width: 10),
              Text(
                'Rider Satisfaction Rating',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          Text(
            '4.8 / 5.0',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD600),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required String labelText,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
      filled: true,
      fillColor: const Color(0xFF151622),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF00E676), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
      ),
    );
  }
}
