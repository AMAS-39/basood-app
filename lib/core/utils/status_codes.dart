class DriverStatus {
  static const driverPickup = 'DriverPickup';
  static const postponed = 'Postponed';
  static const canceled = 'Canceled';
  static const partialCanceled = 'PartialCanceled';
  static const delivered = 'Delivered';
}

class StatusCodes {
  static const int pickedUp = 1;
  static const int delivered = 2;
  static const int returned = 3;
  static const int delayed = 4;
  static const int communicationProblem = 5;
  static const int technicalProblem = 6;
}
