import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _skuController;
  late TextEditingController _barcodeController;
  late TextEditingController _categoryController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _mrpController;
  late TextEditingController _stockController;
  late TextEditingController _alertController;
  late TextEditingController _hsnController;
  late TextEditingController _supplierController;

  double _gstRate = 0.0;
  String _unit = 'Pcs';
  DateTime? _expiryDate;
  bool _isSaving = false;

  final List<String> _units = ['Pcs', 'Kg', 'Gm', 'Ltr', 'Ml', 'Box', 'Meter', 'Packet', 'Set'];
  final List<double> _gstRates = [0.0, 5.0, 12.0, 18.0, 28.0];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _categoryController = TextEditingController(text: p?.category ?? 'General');
    _purchasePriceController = TextEditingController(text: p?.purchasePrice.toString() ?? '0');
    _sellingPriceController = TextEditingController(text: p?.sellingPrice.toString() ?? '');
    _mrpController = TextEditingController(text: p?.mrp.toString() ?? '');
    _stockController = TextEditingController(text: p?.stockQuantity.toString() ?? '0');
    _alertController = TextEditingController(text: p?.minStockAlert.toString() ?? '5');
    _hsnController = TextEditingController(text: p?.hsnCode ?? '');
    _supplierController = TextEditingController(text: p?.supplierName ?? '');

    _gstRate = p?.gstRate ?? 0.0;
    _unit = p?.unit ?? 'Pcs';
    _expiryDate = p?.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _mrpController.dispose();
    _stockController.dispose();
    _alertController.dispose();
    _hsnController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  void _generateRandomBarcode() {
    final random = Random();
    final code = List.generate(12, (_) => random.nextInt(10)).join();
    setState(() {
      _barcodeController.text = code;
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
    if (shop == null) return;

    setState(() => _isSaving = true);

    final sellingPrice = double.tryParse(_sellingPriceController.text.trim()) ?? 0.0;
    final purchasePrice = double.tryParse(_purchasePriceController.text.trim()) ?? 0.0;
    final mrp = double.tryParse(_mrpController.text.trim()) ?? sellingPrice;
    final stock = double.tryParse(_stockController.text.trim()) ?? 0.0;
    final alert = double.tryParse(_alertController.text.trim()) ?? 5.0;

    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      shopId: shop.id,
      name: _nameController.text.trim(),
      sku: _skuController.text.trim(),
      barcode: _barcodeController.text.trim(),
      category: _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim(),
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      mrp: mrp,
      gstRate: _gstRate,
      stockQuantity: stock,
      minStockAlert: alert,
      unit: _unit,
      hsnCode: _hsnController.text.trim(),
      supplierName: _supplierController.text.trim(),
      expiryDate: _expiryDate,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await Provider.of<ProductProvider>(context, listen: false).saveProduct(product);

    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.product == null ? 'Product added successfully!' : 'Product updated!'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Add New Product' : 'Edit Product'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Product?'),
                    content: const Text('Are you sure you want to delete this product?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  final shop = Provider.of<ShopProvider>(context, listen: false).currentShop!;
                  await Provider.of<ProductProvider>(context, listen: false).deleteProduct(widget.product!.id, shop.id);
                  if (mounted) Navigator.pop(context);
                }
              },
            ),
        ],
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
                  // Basic Details
                  _buildSectionTitle('General Information'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Enter product name' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _unit,
                          decoration: const InputDecoration(
                            labelText: 'Unit of Measure',
                            prefixIcon: Icon(Icons.straighten),
                          ),
                          items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _unit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Barcode & SKU
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _barcodeController,
                          decoration: InputDecoration(
                            labelText: 'Barcode',
                            prefixIcon: const Icon(Icons.qr_code),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.autorenew, color: AppTheme.primary),
                              tooltip: 'Generate Barcode',
                              onPressed: _generateRandomBarcode,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _skuController,
                          decoration: const InputDecoration(
                            labelText: 'SKU / Code',
                            prefixIcon: Icon(Icons.tag),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pricing & GST
                  _buildSectionTitle('Pricing & GST Details'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sellingPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Selling Price (Rs.) *',
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Enter selling price' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _mrpController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'MRP (Rs.)',
                            prefixIcon: Icon(Icons.sell_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _purchasePriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price (Rs.)',
                      prefixIcon: Icon(Icons.shopping_bag_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<double>(
                          value: _gstRate,
                          decoration: const InputDecoration(
                            labelText: 'GST Tax Rate',
                            prefixIcon: Icon(Icons.percent),
                          ),
                          items: _gstRates
                              .map((r) => DropdownMenuItem(value: r, child: Text('${r.toStringAsFixed(0)}% GST')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _gstRate = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _hsnController,
                          decoration: const InputDecoration(
                            labelText: 'HSN / SAC Code',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stock & Inventory
                  _buildSectionTitle('Stock & Inventory Tracking'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Current Stock Quantity',
                            prefixIcon: Icon(Icons.warehouse),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _alertController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Low Stock Alert Limit',
                            prefixIcon: Icon(Icons.warning_amber),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _supplierController,
                          decoration: const InputDecoration(
                            labelText: 'Supplier / Vendor Name',
                            prefixIcon: Icon(Icons.local_shipping),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (picked != null) setState(() => _expiryDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date (Optional)',
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _expiryDate != null
                                  ? DateFormat('dd/MM/yyyy').format(_expiryDate!)
                                  : 'Select Expiry Date',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProduct,
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isNew ? 'SAVE PRODUCT' : 'UPDATE PRODUCT'),
                    ),
                  ),
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
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
    );
  }
}
