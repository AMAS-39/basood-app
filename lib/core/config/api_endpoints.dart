class BasoodEndpoints {
  // Branch
  static const branch = _Branch();

  // City
  static const city = _City();

  // Dashboard
  static const dashboard = _Dashboard();

  // Driver
  static const driver = _Driver();

  // DriverOrder
  static const driverOrder = _DriverOrder();

  // Employee
  static const employee = _Employee();

  // Expensive
  static const expensive = _Expensive();

  // Neighborhood
  static const neighborhood = _Neighborhood();

  // Order
  static const order = _Order();

  // Payment
  static const payment = _Payment();

  // Notification
  static const notification = _Notification();

  // Payroll
  static const payroll = _Payroll();

  // Role
  static const role = _Role();

  // Safe
  static const safe = _Safe();

  // Supplier
  static const supplier = _Supplier();

  // SupplierOrder
  static const supplierOrder = _SupplierOrder();

  // Transaction
  static const transaction = _Transaction();

  // Transfer
  static const transfer = _Transfer();

  // User
  static const user = _User();
}

class _Branch {
  const _Branch();

  String get create => '/api/Branch';
  String get getAll => '/api/Branch';
  String update(dynamic id) => '/api/Branch/$id';
  String getById(dynamic id) => '/api/Branch/$id';
  String get list => '/api/Branch/List';
}

class _City {
  const _City();

  String get create => '/api/City';
  String get getAll => '/api/City';
  String update(dynamic id) => '/api/City/$id';
  String getById(dynamic id) => '/api/City/$id';
  String togglerDelete(dynamic id) => '/api/City/TogglerDelete/$id';
  String get list => '/api/City/List';
}

class _Dashboard {
  const _Dashboard();

  String get selfPerStatus => '/api/Dashboard/SelfPerStatus';
  String get listSelfPerStatus => '/api/Dashboard/ListSelfPerStatus';
  String get olderThanDay => '/api/Dashboard/OlderThanDay';
  String get olderThanDayCounter => '/api/Dashboard/OlderThanDayCounter';
}

class _Driver {
  const _Driver();

  String get create => '/api/Driver';
  String get getAll => '/api/Driver';
  String update(dynamic id) => '/api/Driver/$id';
  String getById(dynamic id) => '/api/Driver/$id';
  String togglerDelete(dynamic id) => '/api/Driver/TogglerDelete/$id';
  String get listDriverToCustomer => '/api/Driver/ListDriverToCustomer';
  String get listDriverToOffice => '/api/Driver/ListDriverToOffice';
  String createUser(dynamic id) => '/api/Driver/CreateUser/$id';
}

class _DriverOrder {
  const _DriverOrder();

  String get orderPending => '/api/DriverOrder/OrderPending';
  String get driverPending => '/api/DriverOrder/DriverPending';
  String get receivedOrderPending => '/api/DriverOrder/ReceivedOrderPending';
  String get currentOrderPending => '/api/DriverOrder/CurrentOrderPending';
  String get currentDriverPending => '/api/DriverOrder/CurrentDriverPending';
  String driverChangeAmount(dynamic id) =>
      '/api/DriverOrder/DriverChangeAmount/$id';
}

class _Employee {
  const _Employee();

  String update(dynamic id) => '/api/Employee/$id';
  String getById(dynamic id) => '/api/Employee/$id';
  String get create => '/api/Employee';
  String get getAll => '/api/Employee';
  String changeSalary(dynamic id) => '/api/Employee/ChangeSalary/$id';
  String togglerDelete(dynamic id) => '/api/Employee/TogglerDelete/$id';
  String get list => '/api/Employee/List';
  String createUser(dynamic id) => '/api/Employee/CreateUser/$id';
}

class _Expensive {
  const _Expensive();

  String get create => '/api/Expensive';
  String get getAll => '/api/Expensive';
  String update(dynamic id) => '/api/Expensive/$id';
  String getById(dynamic id) => '/api/Expensive/$id';
}

class _Neighborhood {
  const _Neighborhood();

  String get create => '/api/Neighborhood';
  String get getAll => '/api/Neighborhood';
  String update(dynamic id) => '/api/Neighborhood/$id';
  String getById(dynamic id) => '/api/Neighborhood/$id';
  String get list => '/api/Neighborhood/List';
  String getByCityId(dynamic id) => '/api/Neighborhood/GetByCityId/$id';
}

class _Order {
  const _Order();

  String get create => '/api/Order';
  String get getAll => '/api/Order';
  String orderPending(dynamic id) => '/api/Order/OrderPending/$id';
  String update(dynamic id) => '/api/Order/$id';
  String getById(dynamic id) => '/api/Order/$id';
  String status(dynamic id) => '/api/Order/Status/$id';
  String get orderReport => '/api/Order/OrderReport';
  String get assignOrderPendingToDriver =>
      '/api/Order/AssignOrderPendingToDriver';
  String qrCodes(dynamic num) => '/api/Order/QrCodes/$num';
  String get current => '/api/Order/Current';
}

class _Payment {
  const _Payment();

  String get create => '/api/Payment';
  String get getAll => '/api/Payment';
  String getById(dynamic id) => '/api/Payment/$id';
  String get list => '/api/Payment/List';
  String receive(dynamic id) => '/api/Payment/Receive/$id';
  String reverse(dynamic id) => '/api/Payment/Reverse/$id';
  String get orderReadyForPayment => '/api/Payment/OrderReadyForPayment';
}

class _Notification {
  const _Notification();

  String get getAll => '/api/Notification';
  String markAsRead(dynamic id) => '/api/Notification/$id';
}

class _Payroll {
  const _Payroll();

  String get create => '/api/Payroll';
  String get getAll => '/api/Payroll';
  String update(dynamic id) => '/api/Payroll/$id';
  String getById(dynamic id) => '/api/Payroll/$id';
}

class _Role {
  const _Role();

  String getById(dynamic id) => '/api/Role/$id';
  String update(dynamic id) => '/api/Role/$id';
  String get create => '/api/Role';
  String get getAll => '/api/Role';
  String get permissions => '/api/Role/Permissions';
  String get assign => '/api/Role/Assign';
  String get list => '/api/Role/List';
}

class _Safe {
  const _Safe();

  String get create => '/api/Safe';
  String get getAll => '/api/Safe';
  String update(dynamic id) => '/api/Safe/$id';
  String getById(dynamic id) => '/api/Safe/$id';
  String togglerDelete(dynamic id) => '/api/Safe/TogglerDelete/$id';
  String get list => '/api/Safe/List';
}

class _Supplier {
  const _Supplier();

  String get create => '/api/Supplier';
  String get getAll => '/api/Supplier';
  String update(dynamic id) => '/api/Supplier/$id';
  String getById(dynamic id) => '/api/Supplier/$id';
  String togglerDelete(dynamic id) => '/api/Supplier/TogglerDelete/$id';
  String get list => '/api/Supplier/List';
  String get payments => '/api/Supplier/Payments';
  String get supplierCurrentPayment => '/api/Supplier/SupplierCurrentPayment';
  String createUser(dynamic id) => '/api/Supplier/CreateUser/$id';
  String get balance => '/api/Supplier/Balance';
  String get selfOrderReadyPayment => '/api/Supplier/SelfOrderReadyPayment';
}

class _SupplierOrder {
  const _SupplierOrder();

  String get getAll => '/api/SupplierOrder';
  String get create => '/api/SupplierOrder';
  String get supplierCurrentCancel =>
      '/api/SupplierOrder/SupplierCurrentCancel';
  String update(dynamic id) => '/api/SupplierOrder/$id';
  String getById(dynamic id) => '/api/SupplierOrder/$id';
  String get orderPerDays => '/api/SupplierOrder/OrderPerDays';
  String receivedOrderCanceled(dynamic id) =>
      '/api/SupplierOrder/ReceivedOrderCanceled/$id';
}

class _Transaction {
  const _Transaction();

  String get create => '/api/Transaction';
  String get getAll => '/api/Transaction';
  String update(dynamic id) => '/api/Transaction/$id';
  String getById(dynamic id) => '/api/Transaction/$id';
  String get list => '/api/Transaction/List';
  String orderDetailDriver(dynamic id) =>
      '/api/Transaction/OrderDetailDriver/$id';
}

class _Transfer {
  const _Transfer();

  String update(dynamic id) => '/api/Transfer/$id';
  String getById(dynamic id) => '/api/Transfer/$id';
  String get create => '/api/Transfer';
  String get getAll => '/api/Transfer';
  String get formTo => '/api/Transfer/Form-To';
}

class _User {
  const _User();

  String get login => '/api/User/Login';
  String get loginMobile => '/api/User/LoginMobile';
  String get refreshToken => '/api/User/Refresh-Token';
  String get revokeToken => '/api/User/Revoke-Token';
  String get create => '/api/User';
  String get getAll => '/api/User';
  String update(dynamic id) => '/api/User/$id';
  String getById(dynamic id) => '/api/User/$id';
  String toggleDelete(dynamic id) => '/api/User/ToggleDelete/$id';
  String get uploadPicture => '/api/User/UploadPicture';
  String get removePicture => '/api/User/RemovePicture';
  String get registerFcmToken => '/api/User/FcmToken';
}
