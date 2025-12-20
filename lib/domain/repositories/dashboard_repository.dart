import '../../../infrastructure/dtos/dashboard_dtos.dart';

abstract class DashboardRepository {
  Future<DashboardStatsDto> getDriverStats();
  Future<SupplierDashboardStatsDto> getSupplierStats();
}
