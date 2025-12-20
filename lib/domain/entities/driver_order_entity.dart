class DriverOrderEntity {
  final String id;
  final String code;
  final String pickupAddress;
  final String dropoffAddress;
  final DateTime createdAt;
  
  const DriverOrderEntity({
    required this.id,
    required this.code,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.createdAt,
  });
}
