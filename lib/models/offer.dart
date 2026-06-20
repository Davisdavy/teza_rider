class DeliveryOffer {
  final String id;
  final String deliveryId;
  final String riderId;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  DeliveryOffer({
    required this.id,
    required this.deliveryId,
    required this.riderId,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.updatedAt,
  });

  factory DeliveryOffer.fromJson(Map<String, dynamic> json) {
    return DeliveryOffer(
      id: json['id'] ?? '',
      deliveryId: json['deliveryId'] ?? '',
      riderId: json['riderId'] ?? '',
      status: json['status'] ?? 'PENDING',
      expiresAt: DateTime.parse(json['expiresAt']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deliveryId': deliveryId,
      'riderId': riderId,
      'status': status,
      'expiresAt': expiresAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
