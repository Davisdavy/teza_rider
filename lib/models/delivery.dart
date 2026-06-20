class Delivery {
  final String id;
  final String? merchantId;
  final String? customerId;
  final String? riderId;
  final String pickupAddress;
  final double pickupLatitude;
  final double pickupLongitude;
  final String dropoffAddress;
  final double dropoffLatitude;
  final double dropoffLongitude;
  final String status;
  final double deliveryFee;
  final DateTime? acceptedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Delivery({
    required this.id,
    this.merchantId,
    this.customerId,
    this.riderId,
    required this.pickupAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.dropoffAddress,
    required this.dropoffLatitude,
    required this.dropoffLongitude,
    required this.status,
    required this.deliveryFee,
    this.acceptedAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
  });

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      id: json['id'] ?? '',
      merchantId: json['merchantId'],
      customerId: json['customerId'],
      riderId: json['riderId'],
      pickupAddress: json['pickupAddress'] ?? '',
      pickupLatitude: (json['pickupLatitude'] as num?)?.toDouble() ?? 0.0,
      pickupLongitude: (json['pickupLongitude'] as num?)?.toDouble() ?? 0.0,
      dropoffAddress: json['dropoffAddress'] ?? '',
      dropoffLatitude: (json['dropoffLatitude'] as num?)?.toDouble() ?? 0.0,
      dropoffLongitude: (json['dropoffLongitude'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'PENDING',
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      acceptedAt: json['acceptedAt'] != null ? DateTime.parse(json['acceptedAt']) : null,
      pickedUpAt: json['pickedUpAt'] != null ? DateTime.parse(json['pickedUpAt']) : null,
      deliveredAt: json['deliveredAt'] != null ? DateTime.parse(json['deliveredAt']) : null,
      cancelledAt: json['cancelledAt'] != null ? DateTime.parse(json['cancelledAt']) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchantId': merchantId,
      'customerId': customerId,
      'riderId': riderId,
      'pickupAddress': pickupAddress,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'dropoffAddress': dropoffAddress,
      'dropoffLatitude': dropoffLatitude,
      'dropoffLongitude': dropoffLongitude,
      'status': status,
      'deliveryFee': deliveryFee,
      'acceptedAt': acceptedAt?.toIso8601String(),
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
