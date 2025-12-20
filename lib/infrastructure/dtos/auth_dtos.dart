class LoginRequestDto {
  final String username;
  final String password;
  final String? deviceToken;
  final String? deviceId;

  const LoginRequestDto({
    required this.username,
    required this.password,
    this.deviceToken,
    this.deviceId,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    if (deviceToken != null) 'deviceToken': deviceToken,
    if (deviceId != null) 'deviceId': deviceId,
  };
}

class LoginResponseDto {
  final String id;
  final String name;
  final String role;
  final bool isToCustomer;
  final String accessToken;
  final String refreshToken;
  final String? email;
  final String? phone;
  final String? address;
  final int? supplierId; // Add supplier ID

  const LoginResponseDto({
    required this.id,
    required this.name,
    required this.role,
    required this.isToCustomer,
    required this.accessToken,
    required this.refreshToken,
    this.email,
    this.phone,
    this.address,
    this.supplierId,
  });

  factory LoginResponseDto.fromJson(Map<String, dynamic> json) {
    print('*** Login Response Debug ***');
    print('Full JSON: $json');
    
    final user = json['user'] as Map<String, dynamic>? ?? {};
    print('User data: $user');
    
    final userType = user['userType'] ?? 0;
    print('UserType: $userType');
    
    // Map userType to role
    String role = 'User';
    if (userType == 2) role = 'Driver';
    else if (userType == 3) role = 'Supplier';
    
    print('Mapped role: $role');
    
    // Check if user has driver/supplier data to determine isToCustomer
    final driver = user['driver'];
    final supplier = user['supplier'];
    print('Driver data: $driver');
    print('Supplier data: $supplier');
    
    bool isToCustomer = true; // Default to customer driver

    if (driver != null) {
      // If user has driver data, check if it's customer or supplier driver
      isToCustomer = driver['isToCustomer'] ?? true;
    } else if (supplier != null) {
      // If user is supplier, set isToCustomer based on supplier data
      isToCustomer = supplier['isToCustomer'] ?? false;
    } else {
      // If user has no driver/supplier data, they can't access driver/supplier features
      // This will cause the app to show appropriate error messages
      isToCustomer = true;
    }
    
    print('isToCustomer: $isToCustomer');
    print('Final role: $role, isToCustomer: $isToCustomer');
    print('*** End Debug ***');
    
    return LoginResponseDto(
      id: user['id']?.toString() ?? '',
      name: '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
      role: role,
      isToCustomer: isToCustomer,
      accessToken: json['token'] ?? '',
      refreshToken: json['refreshToken'] ?? '',
      email: user['email'],
      phone: user['phone'],
      address: user['address'],
      supplierId: userType == 3 ? userType : null, // Use userType 3 for Supplier
    );
  }
}

class RefreshTokenResponseDto {
  final String accessToken;
  final String refreshToken;

  const RefreshTokenResponseDto({
    required this.accessToken,
    required this.refreshToken,
  });

  factory RefreshTokenResponseDto.fromJson(Map<String, dynamic> json) => RefreshTokenResponseDto(
    accessToken: json['accessToken'] ?? '',
    refreshToken: json['refreshToken'] ?? '',
  );
}
