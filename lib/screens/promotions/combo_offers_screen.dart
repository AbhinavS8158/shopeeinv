import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/combo_offer.dart';
import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/combo_offer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';

class ComboOffersScreen extends StatefulWidget {
  const ComboOffersScreen({super.key});

  @override
  State<ComboOffersScreen> createState() => _ComboOffersScreenState();
}

class _ComboOffersScreenState extends State<ComboOffersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
      if (shop != null) {
        Provider.of<ComboOfferProvider>(context, listen: false).loadComboOffers(shop.id);
        Provider.of<ProductProvider>(context, listen: false).loadProducts(shop.id);
      }
    });
  }

  void _openAddEditDialog([ComboOffer? existingOffer]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditComboModal(existingOffer: existingOffer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comboProvider = Provider.of<ComboOfferProvider>(context);
    final shop = Provider.of<ShopProvider>(context).currentShop;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combo Offers Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              if (shop != null) {
                comboProvider.loadComboOffers(shop.id);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Combo Offer'),
      ),
      body: comboProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : comboProvider.offers.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comboProvider.offers.length,
                  itemBuilder: (context, index) {
                    final offer = comboProvider.offers[index];
                    return _buildOfferCard(offer, shop?.id ?? '');
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Combo Offers Configured',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Create combo bundles (e.g. Shirt + Jeans @ ₹2,000 or Buy 2 Get 1 Free).\nPOS will auto-detect and apply combo pricing at checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Create First Combo Offer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard(ComboOffer offer, String shopId) {
    String typeLabel = 'Fixed Price';
    Color badgeColor = Colors.teal;
    String valueDetail = 'Rs. ${offer.comboPrice.toStringAsFixed(2)}';

    if (offer.isPercentageDiscount) {
      typeLabel = 'Discount %';
      badgeColor = Colors.orange;
      valueDetail = '${offer.discountPercentage.toStringAsFixed(0)}% OFF';
    } else if (offer.isBuyXGetY) {
      typeLabel = 'Buy X Get Y Free';
      badgeColor = Colors.purple;
      final freeName = offer.freeProductName ?? (offer.items.isNotEmpty ? offer.items.first.productName : 'Product');
      valueDetail = 'Buy ${offer.buyQuantity.toInt()} Get ${offer.freeQuantity.toInt()}x $freeName FREE';
    } else if (offer.isQuantitySpecialPrice) {
      typeLabel = 'Quantity Special Price';
      badgeColor = Colors.deepOrange;
      valueDetail = 'Rs. ${offer.specialPrice.toStringAsFixed(2)} for ${offer.minPurchaseQty.toInt()} Qty';
    }

    final isValid = offer.isValidNow;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isValid ? Colors.grey.shade200 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              offer.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (offer.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          offer.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: offer.isActive,
                  activeThumbColor: AppTheme.primary,
                  onChanged: (val) {
                    Provider.of<ComboOfferProvider>(context, listen: false)
                        .toggleComboOffer(offer.id, val, shopId);
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            // Offer Summary Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sell_outlined, size: 16, color: badgeColor),
                      const SizedBox(width: 6),
                      Text(
                        valueDetail,
                        style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (!isValid && offer.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Out of Date Range',
                      style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (offer.isBuyXGetY) ...[
              const Text(
                'Promotional Rule:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Buy ${offer.buyQuantity.toInt()}x ${offer.items.isNotEmpty ? offer.items.first.productName : 'Product'} -> Get ${offer.freeQuantity.toInt()}x ${offer.freeProductName ?? 'Same Item'} 100% FREE',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.purple),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (offer.isQuantitySpecialPrice) ...[
              const Text(
                'Promotional Rule:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.deepOrange.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.price_check, color: Colors.deepOrange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Buy ${offer.minPurchaseQty.toInt()} or more of ${offer.items.isNotEmpty ? offer.items.first.productName : 'Product'} -> Special Price: Rs. ${offer.specialPrice.toStringAsFixed(2)} per slab',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.deepOrange),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'Required Bundle Items:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: offer.items.map((item) {
                  return Chip(
                    avatar: const CircleAvatar(
                      backgroundColor: AppTheme.primary,
                      radius: 10,
                      child: Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                    label: Text('${item.quantity.toInt()}x ${item.productName}'),
                    labelStyle: const TextStyle(fontSize: 12),
                    backgroundColor: Colors.grey.shade100,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ],
            if (offer.startDate != null || offer.endDate != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Validity: ${offer.startDate != null ? DateFormat('dd/MM/yyyy').format(offer.startDate!) : 'Always'} - ${offer.endDate != null ? DateFormat('dd/MM/yyyy').format(offer.endDate!) : 'Ongoing'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openAddEditDialog(offer),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Combo Offer?'),
                        content: Text('Are you sure you want to delete "${offer.title}"?'),
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
                      Provider.of<ComboOfferProvider>(context, listen: false)
                          .deleteComboOffer(offer.id, shopId);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddEditComboModal extends StatefulWidget {
  final ComboOffer? existingOffer;

  const _AddEditComboModal({this.existingOffer});

  @override
  State<_AddEditComboModal> createState() => _AddEditComboModalState();
}

class _AddEditComboModalState extends State<_AddEditComboModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _comboPriceCtrl;
  late TextEditingController _discountPercentCtrl;
  late TextEditingController _buyQtyCtrl;
  late TextEditingController _freeQtyCtrl;
  late TextEditingController _minPurchaseQtyCtrl;
  late TextEditingController _specialPriceCtrl;

  String _offerType = 'buy_x_get_y';
  String? _qualifyingProductId;
  String? _freeProductId;
  bool _sameProductForFree = true;
  List<ComboItem> _items = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final o = widget.existingOffer;
    _titleCtrl = TextEditingController(text: o?.title ?? '');
    _descCtrl = TextEditingController(text: o?.description ?? '');
    _comboPriceCtrl = TextEditingController(text: o != null && o.comboPrice > 0 ? o.comboPrice.toString() : '');
    _discountPercentCtrl =
        TextEditingController(text: o != null && o.discountPercentage > 0 ? o.discountPercentage.toString() : '');
    _buyQtyCtrl = TextEditingController(
        text: o != null && o.buyQuantity > 0
            ? (o.buyQuantity % 1 == 0 ? o.buyQuantity.toInt().toString() : o.buyQuantity.toString())
            : '1');
    _freeQtyCtrl = TextEditingController(
        text: o != null && o.freeQuantity > 0
            ? (o.freeQuantity % 1 == 0 ? o.freeQuantity.toInt().toString() : o.freeQuantity.toString())
            : '1');
    _minPurchaseQtyCtrl = TextEditingController(
        text: o != null && o.minPurchaseQty > 0
            ? (o.minPurchaseQty % 1 == 0 ? o.minPurchaseQty.toInt().toString() : o.minPurchaseQty.toString())
            : '5');
    _specialPriceCtrl = TextEditingController(text: o != null && o.specialPrice > 0 ? o.specialPrice.toString() : '');
    _offerType = o?.offerType ?? 'buy_x_get_y';
    _items = o != null ? List.from(o.items) : [];
    _startDate = o?.startDate;
    _endDate = o?.endDate;
    _isActive = o?.isActive ?? true;

    if (o != null) {
      if (o.items.isNotEmpty) {
        _qualifyingProductId = o.items.first.productId;
      }
      _freeProductId = o.freeProductId;
      _sameProductForFree = (o.freeProductId == null || o.freeProductId == _qualifyingProductId);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _comboPriceCtrl.dispose();
    _discountPercentCtrl.dispose();
    _buyQtyCtrl.dispose();
    _freeQtyCtrl.dispose();
    _minPurchaseQtyCtrl.dispose();
    _specialPriceCtrl.dispose();
    super.dispose();
  }

  void _showAddProductDialog() {
    final products = Provider.of<ProductProvider>(context, listen: false).products;
    Product? selectedProduct;
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Product to Combo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Product>(
                decoration: const InputDecoration(labelText: 'Select Product *'),
                items: products.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Text('${p.name} (Rs. ${p.sellingPrice.toStringAsFixed(0)})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setDialogState(() => selectedProduct = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Required Quantity in Combo'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedProduct == null) return;
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
                setState(() {
                  _items.removeWhere((i) => i.productId == selectedProduct!.id);
                  _items.add(ComboItem(
                    productId: selectedProduct!.id,
                    productName: selectedProduct!.name,
                    quantity: qty > 0 ? qty : 1.0,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
    if (shop == null) return;
    final allProducts = Provider.of<ProductProvider>(context, listen: false).products;

    List<ComboItem> finalItems = [];
    double finalBuyQty = 1.0;
    String? finalFreeProdId;
    String? finalFreeProdName;
    double finalFreeQty = 1.0;
    double finalSpecialPrice = 0.0;
    double finalMinPurchaseQty = 1.0;
    double finalComboPrice = 0.0;
    double finalDiscountPercent = 0.0;

    if (_offerType == 'buy_x_get_y') {
      if (_qualifyingProductId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select the qualifying purchase product.'), backgroundColor: AppTheme.danger),
        );
        return;
      }
      final qProd = allProducts.firstWhere(
        (p) => p.id == _qualifyingProductId,
        orElse: () => Product(id: _qualifyingProductId!, shopId: shop.id, name: 'Product', sellingPrice: 0),
      );
      finalBuyQty = double.tryParse(_buyQtyCtrl.text.trim()) ?? 1.0;
      if (finalBuyQty <= 0) finalBuyQty = 1.0;

      finalItems = [ComboItem(productId: qProd.id, productName: qProd.name, quantity: finalBuyQty)];

      if (_sameProductForFree) {
        finalFreeProdId = qProd.id;
        finalFreeProdName = qProd.name;
      } else {
        if (_freeProductId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select the free product.'), backgroundColor: AppTheme.danger),
          );
          return;
        }
        final fProd = allProducts.firstWhere(
          (p) => p.id == _freeProductId,
          orElse: () => Product(id: _freeProductId!, shopId: shop.id, name: 'Free Product', sellingPrice: 0),
        );
        finalFreeProdId = fProd.id;
        finalFreeProdName = fProd.name;
      }
      finalFreeQty = double.tryParse(_freeQtyCtrl.text.trim()) ?? 1.0;
      if (finalFreeQty <= 0) finalFreeQty = 1.0;
    } else if (_offerType == 'quantity_special_price') {
      if (_qualifyingProductId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select the product for special pricing.'), backgroundColor: AppTheme.danger),
        );
        return;
      }
      final targetProd = allProducts.firstWhere(
        (p) => p.id == _qualifyingProductId,
        orElse: () => Product(id: _qualifyingProductId!, shopId: shop.id, name: 'Product', sellingPrice: 0),
      );
      finalMinPurchaseQty = double.tryParse(_minPurchaseQtyCtrl.text.trim()) ?? 1.0;
      finalSpecialPrice = double.tryParse(_specialPriceCtrl.text.trim()) ?? 0.0;

      if (finalMinPurchaseQty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Minimum purchase quantity must be greater than 0.'), backgroundColor: AppTheme.danger),
        );
        return;
      }
      if (finalSpecialPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Special promotional price must be greater than 0.'), backgroundColor: AppTheme.danger),
        );
        return;
      }

      finalItems = [ComboItem(productId: targetProd.id, productName: targetProd.name, quantity: finalMinPurchaseQty)];
    } else {
      // Bundle offers (fixed_price / percentage_discount)
      if (_items.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A combo bundle must include at least 2 products.'), backgroundColor: AppTheme.danger),
        );
        return;
      }
      finalItems = _items;
      finalComboPrice = double.tryParse(_comboPriceCtrl.text.trim()) ?? 0.0;
      finalDiscountPercent = double.tryParse(_discountPercentCtrl.text.trim()) ?? 0.0;
    }

    setState(() => _isSaving = true);

    final offer = ComboOffer(
      id: widget.existingOffer?.id ?? const Uuid().v4(),
      shopId: shop.id,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      offerType: _offerType,
      comboPrice: finalComboPrice,
      discountPercentage: finalDiscountPercent,
      items: finalItems,
      buyQuantity: finalBuyQty,
      freeProductId: finalFreeProdId,
      freeProductName: finalFreeProdName,
      freeQuantity: finalFreeQty,
      specialPrice: finalSpecialPrice,
      minPurchaseQty: finalMinPurchaseQty,
      startDate: _startDate,
      endDate: _endDate,
      isActive: _isActive,
      createdAt: widget.existingOffer?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success =
        await Provider.of<ComboOfferProvider>(context, listen: false).saveComboOffer(offer);

    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingOffer == null ? 'Combo offer created!' : 'Combo offer updated!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingOffer == null ? 'Create Combo Offer' : 'Edit Combo Offer',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Offer Title *',
                  hintText: 'e.g. Shirt + Jeans Combo Offer',
                  prefixIcon: Icon(Icons.local_offer),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter offer title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'e.g. Buy Shirt & Jeans together for ₹2,000',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 16),

              // Offer Type
              DropdownButtonFormField<String>(
                value: _offerType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Promotional Offer Type *',
                  prefixIcon: Icon(Icons.category),
                ),
                items: const [
                  DropdownMenuItem(value: 'buy_x_get_y', child: Text('Buy X Get Y Free (Free Gift / Item)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'quantity_special_price', child: Text('Quantity-Based Special Price (e.g. 5 kg for ₹250)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'fixed_price', child: Text('Fixed Bundle Price (e.g. ₹2,000 for set)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'percentage_discount', child: Text('Bundle Discount % (e.g. 15% OFF bundle)', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _offerType = val);
                },
              ),
              const SizedBox(height: 16),

              if (_offerType == 'buy_x_get_y') ...[
                // --- BUY X GET Y FREE CONFIGURATION ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.card_giftcard, color: Colors.purple, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Buy X Get Y Free Configuration',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.purple),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Consumer<ProductProvider>(
                        builder: (ctx, prodProv, _) {
                          return DropdownButtonFormField<String>(
                            value: _qualifyingProductId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Qualifying Purchase Product (Buy X) *',
                              prefixIcon: Icon(Icons.shopping_bag_outlined),
                            ),
                            items: prodProv.products.map((p) {
                              return DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} (₹${p.sellingPrice.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _qualifyingProductId = val),
                            validator: (v) => _offerType == 'buy_x_get_y' && (v == null || v.isEmpty)
                                ? 'Select purchase product'
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _buyQtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Purchase Quantity Required (X) *',
                          hintText: 'e.g. 1 (Buy 1)',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (v) {
                          if (_offerType == 'buy_x_get_y') {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Enter valid quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Free Item is the Same Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: const Text('e.g. Buy 1 Colgate Get 1 Colgate Free', style: TextStyle(fontSize: 11)),
                        value: _sameProductForFree,
                        activeThumbColor: Colors.purple,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _sameProductForFree = val),
                      ),
                      if (!_sameProductForFree) ...[
                        const SizedBox(height: 8),
                        Consumer<ProductProvider>(
                          builder: (ctx, prodProv, _) {
                            return DropdownButtonFormField<String>(
                              value: _freeProductId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Free Product (Get Y Free) *',
                                prefixIcon: Icon(Icons.redeem),
                              ),
                              items: prodProv.products.map((p) {
                                return DropdownMenuItem(
                                  value: p.id,
                                  child: Text('${p.name} (₹${p.sellingPrice.toStringAsFixed(0)})', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _freeProductId = val),
                              validator: (v) => _offerType == 'buy_x_get_y' && !_sameProductForFree && (v == null || v.isEmpty)
                                  ? 'Select free product'
                                  : null,
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _freeQtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Free Product Quantity (Y) *',
                          hintText: 'e.g. 1 (Get 1 Free)',
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        validator: (v) {
                          if (_offerType == 'buy_x_get_y') {
                            final n = double.tryParse(v ?? '');
                            if (n == null || n <= 0) return 'Enter valid free quantity';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '💡 When cashier adds the required purchase quantity to POS, the system automatically adds the free item with 100% discount (₹0.00). If the purchase quantity drops or item is removed, the free item is updated or removed automatically.',
                        style: TextStyle(fontSize: 11, color: Colors.purple.shade900, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ] else if (_offerType == 'quantity_special_price') ...[
                // --- QUANTITY-BASED SPECIAL PRICING ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepOrange.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.price_check, color: Colors.deepOrange, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Quantity-Based Special Price Configuration',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.deepOrange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Consumer<ProductProvider>(
                        builder: (ctx, prodProv, _) {
                          return DropdownButtonFormField<String>(
                            value: _qualifyingProductId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Target Product *',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                            items: prodProv.products.map((p) {
                              return DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} (Normal: ₹${p.sellingPrice.toStringAsFixed(0)}/${p.unit})', overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _qualifyingProductId = val),
                            validator: (v) => _offerType == 'quantity_special_price' && (v == null || v.isEmpty)
                                ? 'Select target product'
                                : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _minPurchaseQtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Min Purchase Qty *',
                                hintText: 'e.g. 5',
                                prefixIcon: Icon(Icons.shopping_cart_outlined),
                              ),
                              validator: (v) {
                                if (_offerType == 'quantity_special_price') {
                                  final n = double.tryParse(v ?? '');
                                  if (n == null || n <= 0) return 'Enter min qty';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _specialPriceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Special Price (Rs.) *',
                                hintText: 'e.g. 250',
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              validator: (v) {
                                if (_offerType == 'quantity_special_price') {
                                  final n = double.tryParse(v ?? '');
                                  if (n == null || n <= 0) return 'Enter price';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '💡 Example: Normal price ₹60/kg. When customer buys 5 kg, special price is ₹250 instead of ₹300. If quantity drops below 5 kg, price automatically reverts to regular selling price.',
                        style: TextStyle(fontSize: 11, color: Colors.deepOrange.shade900, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // --- BUNDLE FIXED PRICE / PERCENTAGE DISCOUNT ---
                if (_offerType == 'fixed_price')
                  TextFormField(
                    controller: _comboPriceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Special Combo Total Price (Rs.) *',
                      hintText: 'e.g. 2000.00',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    validator: (v) {
                      if (_offerType == 'fixed_price') {
                        if (v == null || v.trim().isEmpty) return 'Enter combo price';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0) return 'Invalid price';
                      }
                      return null;
                    },
                  )
                else if (_offerType == 'percentage_discount')
                  TextFormField(
                    controller: _discountPercentCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Bundle Discount Percentage (%) *',
                      hintText: 'e.g. 15',
                      prefixIcon: Icon(Icons.percent),
                    ),
                    validator: (v) {
                      if (_offerType == 'percentage_discount') {
                        if (v == null || v.trim().isEmpty) return 'Enter discount %';
                        final n = double.tryParse(v);
                        if (n == null || n <= 0 || n > 100) return 'Enter 1-100%';
                      }
                      return null;
                    },
                  ),
                const SizedBox(height: 20),

                // Products in Combo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Eligible Products in Combo',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    TextButton.icon(
                      onPressed: _showAddProductDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Product'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text(
                        'No products added yet. Add at least 2 products to create a combo.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Column(
                    children: _items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 18, color: Colors.indigo),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${item.quantity.toInt()}x ${item.productName}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _items.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
              const SizedBox(height: 16),

              // Date Range
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setState(() => _startDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Date (Optional)',
                          prefixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(
                          _startDate != null ? DateFormat('dd/MM/yyyy').format(_startDate!) : 'Immediately',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) setState(() => _endDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Date (Optional)',
                          prefixIcon: Icon(Icons.calendar_today, size: 16),
                        ),
                        child: Text(
                          _endDate != null ? DateFormat('dd/MM/yyyy').format(_endDate!) : 'Ongoing',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Offer is Active', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Inactive offers will not be detected or applied in POS'),
                value: _isActive,
                activeThumbColor: AppTheme.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(widget.existingOffer == null ? 'CREATE COMBO OFFER' : 'UPDATE COMBO OFFER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
