class DashboardStatsDto {
  final int undeliveredReceipts;
  final int cashReceipts;
  final int exchangeAndReturns;
  final int todaysCuts;
  final int reachedRecipient;
  final int receivedAtOffice;
  final int preparedForDistribution;
  final int returned;
  final int communicationProblem;
  final int delayed;
  final int technicalProblem;

  const DashboardStatsDto({
    required this.undeliveredReceipts,
    required this.cashReceipts,
    required this.exchangeAndReturns,
    required this.todaysCuts,
    required this.reachedRecipient,
    required this.receivedAtOffice,
    required this.preparedForDistribution,
    required this.returned,
    required this.communicationProblem,
    required this.delayed,
    required this.technicalProblem,
  });

  factory DashboardStatsDto.fromJson(Map<String, dynamic> json) {
    return DashboardStatsDto(
      undeliveredReceipts: json['undeliveredReceipts'] ?? 0,
      cashReceipts: json['cashReceipts'] ?? 0,
      exchangeAndReturns: json['exchangeAndReturns'] ?? 0,
      todaysCuts: json['todaysCuts'] ?? 0,
      reachedRecipient: json['reachedRecipient'] ?? 0,
      receivedAtOffice: json['receivedAtOffice'] ?? 0,
      preparedForDistribution: json['preparedForDistribution'] ?? 0,
      returned: json['returned'] ?? 0,
      communicationProblem: json['communicationProblem'] ?? 0,
      delayed: json['delayed'] ?? 0,
      technicalProblem: json['technicalProblem'] ?? 0,
    );
  }
}

class SupplierDashboardStatsDto {
  final int todaysOrders;
  final int totalOrders;
  final int pendingOrders;
  final int deliveredOrders;
  final int canceledOrders;
  final int totalPayments;
  final int delayedOrders;
  final int technicalProblems;

  const SupplierDashboardStatsDto({
    required this.todaysOrders,
    required this.totalOrders,
    required this.pendingOrders,
    required this.deliveredOrders,
    required this.canceledOrders,
    required this.totalPayments,
    required this.delayedOrders,
    required this.technicalProblems,
  });

  factory SupplierDashboardStatsDto.fromJson(Map<String, dynamic> json) {
    return SupplierDashboardStatsDto(
      todaysOrders: json['todaysOrders'] ?? 0,
      totalOrders: json['totalOrders'] ?? 0,
      pendingOrders: json['pendingOrders'] ?? 0,
      deliveredOrders: json['deliveredOrders'] ?? 0,
      canceledOrders: json['canceledOrders'] ?? 0,
      totalPayments: json['totalPayments'] ?? 0,
      delayedOrders: json['delayedOrders'] ?? 0,
      technicalProblems: json['technicalProblems'] ?? 0,
    );
  }
}
