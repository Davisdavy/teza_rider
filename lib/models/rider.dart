class RiderProfile {
  final String id;
  final String userId;
  final String vehicleType;
  final String vehiclePlateNum;
  final bool available;
  final String onboardingStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  RiderProfile({
    required this.id,
    required this.userId,
    required this.vehicleType,
    required this.vehiclePlateNum,
    required this.available,
    required this.onboardingStatus,
    this.createdAt,
    this.updatedAt,
  });

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    return RiderProfile(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      vehicleType: json['vehicleType'] ?? '',
      vehiclePlateNum: json['vehiclePlateNum'] ?? '',
      available: json['available'] ?? false,
      onboardingStatus: json['onboardingStatus'] ?? 'PENDING',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'vehicleType': vehicleType,
      'vehiclePlateNum': vehiclePlateNum,
      'available': available,
      'onboardingStatus': onboardingStatus,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
