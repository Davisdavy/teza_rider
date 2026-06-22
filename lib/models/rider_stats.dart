class RiderStats {
  final int completedDeliveries;
  final int cancelledDeliveries;
  final int declinedOffers;
  final int expiredOffers;

  RiderStats({
    required this.completedDeliveries,
    required this.cancelledDeliveries,
    required this.declinedOffers,
    required this.expiredOffers,
  });

  factory RiderStats.fromJson(Map<String, dynamic> json) {
    return RiderStats(
      completedDeliveries: json['completedDeliveries'] ?? 0,
      cancelledDeliveries: json['cancelledDeliveries'] ?? 0,
      declinedOffers: json['declinedOffers'] ?? 0,
      expiredOffers: json['expiredOffers'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completedDeliveries': completedDeliveries,
      'cancelledDeliveries': cancelledDeliveries,
      'declinedOffers': declinedOffers,
      'expiredOffers': expiredOffers,
    };
  }
}
