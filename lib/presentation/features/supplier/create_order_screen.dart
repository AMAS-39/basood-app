import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_field.dart';
import '../../providers/use_case_providers.dart';
import '../auth/auth_controller.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
      final _productNameController = TextEditingController();
      final _productAmountController = TextEditingController();
      final _receiverPhoneController = TextEditingController();
      final _addressController = TextEditingController();
      final _orderNoController = TextEditingController();
      final _remarkController = TextEditingController();
  
  bool _isLoading = false;
  int _selectedCityId = 1; // Default city ID
  int _selectedNeighborhoodId = 1; // Default neighborhood ID

  @override
  void dispose() {
        _productNameController.dispose();
        _productAmountController.dispose();
        _receiverPhoneController.dispose();
        _addressController.dispose();
        _orderNoController.dispose();
        _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Order'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Information
              _buildSectionHeader('Product Information'),
              const SizedBox(height: 16),
              
              AppField(
                label: 'Product Name',
                controller: _productNameController,
                hint: 'Enter product name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              AppField(
                label: 'Product Amount',
                controller: _productAmountController,
                hint: 'Enter total amount',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter product amount';
                  }
                  final amount = int.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Receiver Information
              _buildSectionHeader('Receiver Information'),
              const SizedBox(height: 16),
              
              AppField(
                label: 'Receiver Phone Number',
                controller: _receiverPhoneController,
                hint: 'Enter receiver phone number',
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter receiver phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
                  AppField(
                    label: 'Delivery Address',
                    controller: _addressController,
                    hint: 'Enter delivery address',
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter delivery address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // City Selection
                  DropdownButtonFormField<int>(
                    value: _selectedCityId,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Sulaymaniyah')),
                      DropdownMenuItem(value: 2, child: Text('Erbil')),
                      DropdownMenuItem(value: 3, child: Text('Duhok')),
                      DropdownMenuItem(value: 4, child: Text('Kirkuk')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCityId = value ?? 1;
                      });
                    },
                    validator: (value) {
                      if (value == null || value <= 0) {
                        return 'Please select a city';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Neighborhood Selection
                  DropdownButtonFormField<int>(
                    value: _selectedNeighborhoodId,
                    decoration: const InputDecoration(
                      labelText: 'Neighborhood',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Downtown')),
                      DropdownMenuItem(value: 2, child: Text('University Area')),
                      DropdownMenuItem(value: 3, child: Text('Industrial Zone')),
                      DropdownMenuItem(value: 4, child: Text('Residential Area')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedNeighborhoodId = value ?? 1;
                      });
                    },
                    validator: (value) {
                      if (value == null || value <= 0) {
                        return 'Please select a neighborhood';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
              
              // Order Details
              _buildSectionHeader('Order Details'),
              const SizedBox(height: 16),
              
                  AppField(
                    label: 'Order Number',
                    controller: _orderNoController,
                    hint: 'Enter order number',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter order number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
              
              AppField(
                label: 'Remark (Optional)',
                controller: _remarkController,
                hint: 'Enter any additional notes',
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              
              // Create Button
              AppButton(
                text: 'Create Order',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _createOrder,
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.teal[800],
      ),
    );
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final createUC = ref.read(createSupplierOrderUCProvider);
      final authState = ref.read(authControllerProvider);
      final supplierId = authState.user?.supplierId;
      
      if (supplierId == null) {
        throw Exception('Supplier ID not found. Please log in again.');
      }

          await createUC.call(
            productName: _productNameController.text.trim(),
            productAmount: int.parse(_productAmountController.text.trim()),
            receiverPrimaryNumber: _receiverPhoneController.text.trim(),
            address: _addressController.text.trim(),
            orderNo: _orderNoController.text.trim(),
            remark: _remarkController.text.trim(),
            toCityId: _selectedCityId,
            neighborhoodId: _selectedNeighborhoodId,
            supplierId: supplierId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order created successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating order: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}