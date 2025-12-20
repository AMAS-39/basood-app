class PaymentDto {
  final String id;
  final double amount;
  final String date;
  final String note;

  const PaymentDto({
    required this.id,
    required this.amount,
    required this.date,
    required this.note,
  });

  factory PaymentDto.fromJson(Map<String, dynamic> json) => PaymentDto(
    id: json['id']?.toString() ?? '',
    amount: (json['amount'] ?? 0.0).toDouble(),
    date: json['date'] ?? '',
    note: json['note'] ?? '',
  );
}
