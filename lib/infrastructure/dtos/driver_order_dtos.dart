class DriverOrderDto {
  final String id;
  final String code;
  final String pickupAddress;
  final String dropoffAddress;
  final String createdAt;

  const DriverOrderDto({
    required this.id,
    required this.code,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.createdAt,
  });

  factory DriverOrderDto.fromJson(Map<String, dynamic> json) => DriverOrderDto(
    id: json['id']?.toString() ?? '',
    code: json['code'] ?? '',
    pickupAddress: json['pickupAddress'] ?? '',
    dropoffAddress: json['dropoffAddress'] ?? '',
    createdAt: json['createdAt'] ?? '',
  );
}

class UpdateOrderStatusDto {
  final String status;

  const UpdateOrderStatusDto({required this.status});

  Map<String, dynamic> toJson() => {'status': status};
}

class ChangeAmountDto {
  final double newAmount;

  const ChangeAmountDto({required this.newAmount});

  Map<String, dynamic> toJson() => {'newAmount': newAmount};
}
