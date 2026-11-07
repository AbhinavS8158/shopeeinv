import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/shop_profile.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/shop_provider.dart';
import 'license_request_screen.dart';

class ShopSetupScreen extends StatefulWidget {
  final ShopProfile? existingShop;

  const ShopSetupScreen({super.key, this.existingShop});

  @override
  State<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends State<ShopSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _shopNameController;
  late TextEditingController _ownerNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _gstinController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  late TextEditingController _upiIdController;
  late TextEditingController _prefixController;
  late TextEditingController _termsController;

  String _businessType = 'Retail Store';
  String _invoiceType = 'a4';
  bool _isTaxInclusive = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final shop = widget.existingShop;
    _shopNameController = TextEditingController(text: shop?.shopName ?? '');
    _ownerNameController = TextEditingController(text: shop?.ownerName ?? '');
    _phoneController = TextEditingController(text: shop?.phone ?? '');
    _emailController = TextEditingController(text: shop?.email ?? '');
    _gstinController = TextEditingController(text: shop?.gstin ?? '');
    _addressController = TextEditingController(text: shop?.address ?? '');
    _cityController = TextEditingController(text: shop?.city ?? '');
    _stateController = TextEditingController(text: shop?.state ?? 'Kerala');
    _pincodeController = TextEditingController(text: shop?.pincode ?? '');
    _upiIdController = TextEditingController(text: shop?.upiId ?? '');
    _prefixController = TextEditingController(text: shop?.invoicePrefix ?? 'INV-');
    _termsController = TextEditingController(
      text: shop?.termsAndConditions ??
          'Goods once sold cannot be taken back without original bill. Thank you for shopping with us!',
    );
    _invoiceType = shop?.defaultInvoiceType ?? 'a4';
    _isTaxInclusive = shop?.isTaxInclusive ?? false;
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _upiIdController.dispose();
    _prefixController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _saveShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final shopId = widget.existingShop?.id ?? const Uuid().v4();
    final ownerId = widget.existingShop?.ownerId ?? 'owner_${DateTime.now().millisecondsSinceEpoch}';

    final shop = ShopProfile(
      id: shopId,
      ownerId: ownerId,
      shopName: _shopNameController.text.trim(),
      ownerName: _ownerNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      gstin: _gstinController.text.trim().toUpperCase(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      upiId: _upiIdController.text.trim(),
      invoicePrefix: _prefixController.text.trim().toUpperCase(),
      defaultInvoiceType: _invoiceType,
      termsAndConditions: _termsController.text.trim(),
      isTaxInclusive: _isTaxInclusive,
      createdAt: widget.existingShop?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    final success = await shopProvider.createOrUpdateShop(shop);

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingShop == null
              ? 'Shop setup completed successfully!'
              : 'Shop details updated!'),
          backgroundColor: AppTheme.success,
        ),
      );

      if (widget.existingShop == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LicenseRequestScreen(
              shop: shop,
              businessType: _businessType,
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existingShop == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Shop Setup & Business Profile' : 'Edit Shop Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryLight.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/icon/app_logo.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.storefront, color: AppTheme.primary, size: 32),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isNew ? 'Welcome! Set up your Business' : 'Customize Shop Information',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Your invoices, receipts, and reports will carry these details and VAT / TRN numbers.',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Basic Details Section
                  _buildSectionTitle('Business & Contact Details'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _businessType,
                          decoration: const InputDecoration(
                            labelText: 'Business Type *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Retail Store', child: Text('Retail Store')),
                            DropdownMenuItem(value: 'Supermarket / Grocery', child: Text('Supermarket / Grocery')),
                            DropdownMenuItem(value: 'Wholesale & Distribution', child: Text('Wholesale & Distribution')),
                            DropdownMenuItem(value: 'Pharmacy / Medical', child: Text('Pharmacy / Medical')),
                            DropdownMenuItem(value: 'Electronics & Mobile', child: Text('Electronics & Mobile')),
                            DropdownMenuItem(value: 'General Store', child: Text('General Store')),
                            DropdownMenuItem(value: 'Restaurant / Cafe', child: Text('Restaurant / Cafe')),
                            DropdownMenuItem(value: 'Other Business', child: Text('Other Business')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _businessType = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _shopNameController,
                          decoration: const InputDecoration(
                            labelText: 'Shop / Business Name *',
                            prefixIcon: Icon(Icons.business),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Enter shop name' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _ownerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Owner / Contact Person *',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Enter owner name' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number *',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Enter phone number' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email Address (Optional)',
                            prefixIcon: Icon(Icons.email),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // VAT & Tax Section
                  _buildSectionTitle('Tax & Payment Configuration'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _gstinController,
                          decoration: const InputDecoration(
                            labelText: 'VAT / TRN Number (Optional)',
                            hintText: 'e.g. 32AAAAA0000A1Z5',
                            prefixIcon: Icon(Icons.receipt_long),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _upiIdController,
                          decoration: const InputDecoration(
                            labelText: 'Shop UPI ID (for Payment QR)',
                            hintText: 'e.g. shopname@okaxis / gpay',
                            prefixIcon: Icon(Icons.qr_code_2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address Section
                  _buildSectionTitle('Location / Address'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Street Address *',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter shop address' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _cityController,
                          decoration: const InputDecoration(labelText: 'City / Town'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _pincodeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'PIN Code'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(labelText: 'State'),
                  ),
                  const SizedBox(height: 24),

                  // Invoice Customization
                  _buildSectionTitle('Invoice & Print Format'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _prefixController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Number Prefix',
                      hintText: 'INV-',
                      prefixIcon: Icon(Icons.tag),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _invoiceType,
                    decoration: const InputDecoration(
                      labelText: 'Default Print Layout',
                      prefixIcon: Icon(Icons.print),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'a4',
                        child: Text('A4 Standard VAT Invoice', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'thermal_58',
                        child: Text('Thermal Receipt (58mm)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: 'thermal_80',
                        child: Text('Thermal Receipt (80mm)', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _invoiceType = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _termsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Terms & Conditions / Bill Footer Note',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveShop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isNew ? 'SAVE SHOP DETAILS' : 'UPDATE SHOP PROFILE',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryDark,
      ),
    );
  }
}
