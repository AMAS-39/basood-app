class UserEntity {
  final String id;
  final String name;
  final String role; // 'Driver' | 'Supplier'
  final bool isToCustomer;
  final String? email;
  final String? phone;
  final String? address;
  final int? supplierId; // Add supplier ID for supplier users
  
  const UserEntity({
    required this.id,
    required this.name,
    required this.role,
    required this.isToCustomer,
    this.email,
    this.phone,
    this.address,
    this.supplierId,
  });
}
