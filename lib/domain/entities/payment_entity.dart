class PaymentEntity {
  final String id;
  final double amount;
  final DateTime date;
  final String note;
  
  const PaymentEntity({
    required this.id,
    required this.amount,
    required this.date,
    required this.note,
  });
}
