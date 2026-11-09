import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
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
  late TextEditingController _discountValueController;
  late TextEditingController _maxDiscountPercentController;

  double _gstRate = 0.0;
  bool _isTaxIncluded = false;
  String _discountType = 'none'; // 'none', 'percentage', 'fixed'
  List<QuantityTier> _quantityTiers = [];
  String _imageBase64 = '';
  bool _isPickingImage = false;
  String _unit = 'Pcs';
  DateTime? _expiryDate;
  bool _isSaving = false;

  final List<String> _units = ['Pcs', 'Kg', 'Gm', 'Ltr', 'Ml', 'Box', 'Meter', 'Packet', 'Set'];
  final List<double> _gstRates = [0.0, 5.0, 10.0, 12.0, 15.0, 18.0, 20.0, 28.0];

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
    _discountType = p?.discountType ?? 'none';
    _discountValueController = TextEditingController(
      text: (p?.discountValue ?? 0) > 0 ? p!.discountValue.toString() : '',
    );
    _maxDiscountPercentController = TextEditingController(
      text: (p?.maxDiscountPercent ?? 100) < 100 ? p!.maxDiscountPercent.toString() : '',
    );
    _quantityTiers = List.from(p?.quantityTiers ?? []);

    _gstRate = p?.gstRate ?? 0.0;
    _isTaxIncluded = p?.isTaxIncluded ?? false;
    _imageBase64 = p?.imageBase64 ?? '';
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
    _discountValueController.dispose();
    _maxDiscountPercentController.dispose();
    super.dispose();
  }

  void _generateRandomBarcode() {
    final random = Random();
    final code = List.generate(12, (_) => random.nextInt(10)).join();
    setState(() {
      _barcodeController.text = code;
    });
  }

  Future<void> _pickImage() async {
    setState(() => _isPickingImage = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final resized = img.copyResize(decoded, width: decoded.width > 600 ? 600 : decoded.width);
          final jpgBytes = img.encodeJpg(resized, quality: 75);
          setState(() {
            _imageBase64 = base64Encode(jpgBytes);
          });
        } else {
          setState(() {
            _imageBase64 = base64Encode(bytes);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
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
    final discountVal = double.tryParse(_discountValueController.text.trim()) ?? 0.0;
    final maxDiscPercent = double.tryParse(_maxDiscountPercentController.text.trim()) ?? 100.0;
    final tiersJson = _quantityTiers.isNotEmpty
        ? jsonEncode(_quantityTiers.map((t) => t.toMap()).toList())
        : '';

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
      isTaxIncluded: _isTaxIncluded,
      imageBase64: _imageBase64,
      stockQuantity: stock,
      minStockAlert: alert,
      unit: _unit,
      hsnCode: _hsnController.text.trim(),
      supplierName: _supplierController.text.trim(),
      expiryDate: _expiryDate,
      discountType: _discountType,
      discountValue: discountVal,
      maxDiscountPercent: maxDiscPercent,
      tierPricingJson: tiersJson,
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
                  // Product Photo Upload (Optional)
                  Center(
                    child: Column(
                      children: [
                        InkWell(
                          onTap: _isPickingImage ? null : _pickImage,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _imageBase64.isNotEmpty ? AppTheme.primary : Colors.grey.shade300,
                                width: 1.5,
                              ),
                            ),
                            child: _isPickingImage
                                ? const Center(child: CircularProgressIndicator())
                                : _imageBase64.isNotEmpty
                                    ? Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: Image.memory(
                                              base64Decode(_imageBase64),
                                              width: 130,
                                              height: 130,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: InkWell(
                                              onTap: () => setState(() => _imageBase64 = ''),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.grey.shade600),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Add Photo',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                          ),
                                          Text(
                                            '(Optional)',
                                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ),
                          ),
                        ),
                        if (_imageBase64.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Change Photo', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

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

                  // Pricing & VAT
                  _buildSectionTitle('Pricing & VAT Details'),
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
                            labelText: 'VAT Tax Rate',
                            prefixIcon: Icon(Icons.percent),
                          ),
                          items: _gstRates
                              .map((r) => DropdownMenuItem(value: r, child: Text('${r.toStringAsFixed(0)}% VAT')))
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
                  const SizedBox(height: 16),

                  // Tax Included / Excluded Configuration
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isTaxIncluded ? Colors.teal.shade50 : Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isTaxIncluded ? Colors.teal.shade300 : Colors.blueGrey.shade200,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isTaxIncluded ? Icons.check_circle : Icons.remove_circle_outline,
                                  color: _isTaxIncluded ? Colors.teal.shade800 : Colors.blueGrey.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isTaxIncluded ? 'Tax Included (Price includes VAT)' : 'Tax Excluded (Price excludes VAT)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: _isTaxIncluded ? Colors.teal.shade900 : Colors.blueGrey.shade900,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _isTaxIncluded,
                              activeThumbColor: Colors.teal.shade700,
                              onChanged: (val) {
                                setState(() => _isTaxIncluded = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isTaxIncluded
                              ? '• Tax Included: The product price already includes tax. During billing, the system will extract the tax without adding extra tax.'
                              : '• Tax Excluded: The product price does not include tax. During billing, the system will calculate tax separately and add it to the product price.',
                          style: TextStyle(
                            fontSize: 11,
                            color: _isTaxIncluded ? Colors.teal.shade900 : Colors.blueGrey.shade700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Promotional Discount & Bulk Pricing
                  _buildSectionTitle('Discount & Bulk Pricing Configuration'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.local_offer_outlined, color: AppTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Product Default Discount',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Configure a default discount applied automatically in POS cart, and restrict the cashier max allowable discount.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: _discountType,
                                decoration: const InputDecoration(
                                  labelText: 'Discount Type',
                                  prefixIcon: Icon(Icons.percent),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'none', child: Text('No Default Discount')),
                                  DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                                  DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount (Rs.)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _discountType = val);
                                },
                              ),
                            ),
                            if (_discountType != 'none') ...[
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _discountValueController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: _discountType == 'percentage' ? 'Discount (%)' : 'Discount (Rs.)',
                                    prefixIcon: Icon(_discountType == 'percentage' ? Icons.percent : Icons.currency_rupee),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _maxDiscountPercentController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Maximum Allowed Discount Limit (%)',
                            hintText: 'e.g. 20 (Prevents unauthorized cashier discounts)',
                            prefixIcon: Icon(Icons.shield_outlined),
                          ),
                        ),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.layers_outlined, color: Colors.indigo, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Quantity-Based Pricing (Bulk Pricing)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _showAddTierDialog,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Tier'),
                            ),
                          ],
                        ),
                        Text(
                          'Offer wholesale/volume prices automatically when customer buys certain quantities (e.g. 5-9 units at Rs. 90, 10+ at Rs. 80).',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 10),
                        if (_quantityTiers.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Center(
                              child: Text(
                                'No bulk pricing tiers configured yet. Standard selling price applies to all quantities.',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: _quantityTiers.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final tier = entry.value;
                              final rangeText = tier.maxQty != null
                                  ? '${tier.minQty.toInt()} - ${tier.maxQty!.toInt()} $_unit'
                                  : '${tier.minQty.toInt()}+ $_unit';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.indigo.shade100),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.check_circle_outline, size: 16, color: Colors.indigo),
                                        SizedBox(width: 8),
                                      ],
                                    ),
                                    Text(
                                      rangeText,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Rs. ${tier.unitPrice.toStringAsFixed(2)} / $_unit',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        setState(() {
                                          _quantityTiers.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
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

  void _showAddTierDialog() {
    final minQtyCtrl = TextEditingController();
    final maxQtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final tierFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bulk Pricing Tier'),
        content: Form(
          key: tierFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Define a special unit price when purchase quantity falls within this range.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: minQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Min Qty *',
                        hintText: 'e.g. 5',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: maxQtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Max Qty',
                        hintText: 'e.g. 9 (or leave blank for 5+)',
                      ),
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          final n = double.tryParse(v);
                          final minN = double.tryParse(minQtyCtrl.text);
                          if (n == null) return 'Invalid';
                          if (minN != null && n < minN) return 'Must be >= Min';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Special Unit Price (Rs.) *',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter unit price';
                  final n = double.tryParse(v);
                  if (n == null || n < 0) return 'Invalid price';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (tierFormKey.currentState?.validate() == true) {
                final minQ = double.parse(minQtyCtrl.text.trim());
                final maxQ = maxQtyCtrl.text.trim().isNotEmpty ? double.parse(maxQtyCtrl.text.trim()) : null;
                final price = double.parse(priceCtrl.text.trim());
                setState(() {
                  _quantityTiers.add(QuantityTier(minQty: minQ, maxQty: maxQ, unitPrice: price));
                  _quantityTiers.sort((a, b) => a.minQty.compareTo(b.minQty));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Tier'),
          ),
        ],
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
