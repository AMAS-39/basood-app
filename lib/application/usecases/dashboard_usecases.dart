import '../../../domain/repositories/dashboard_repository.dart';
import '../../../infrastructure/dtos/dashboard_dtos.dart';

class GetDriverStatsUC {
  final DashboardRepository repo;
  GetDriverStatsUC(this.repo);

  Future<DashboardStatsDto> call() => repo.getDriverStats();
}

class GetSupplierStatsUC {
  final DashboardRepository repo;
  GetSupplierStatsUC(this.repo);

  Future<SupplierDashboardStatsDto> call() => repo.getSupplierStats();
}
