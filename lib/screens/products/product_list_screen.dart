import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import 'add_edit_product_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showOnlyLowStock = false;
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
      if (shop != null) {
        Provider.of<ProductProvider>(context, listen: false).loadProducts(shop.id);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showBarcodeDialog(Product product) {
    if (product.barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No barcode assigned to this product.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BarcodeWidget(
              barcode: Barcode.code128(),
              data: product.barcode,
              width: 240,
              height: 100,
            ),
            const SizedBox(height: 12),
            Text('Barcode: ${product.barcode}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Price: ${currency.format(product.sellingPrice)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prodProvider = Provider.of<ProductProvider>(context);

    var list = _showOnlyLowStock ? prodProvider.lowStockProducts : prodProvider.filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Inventory'),
        actions: [
          IconButton(
            icon: Icon(_showOnlyLowStock ? Icons.warning : Icons.warning_amber_outlined),
            tooltip: 'Filter Low Stock',
            onPressed: () {
              setState(() => _showOnlyLowStock = !_showOnlyLowStock);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('ADD PRODUCT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditProductScreen()),
          );
        },
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search products by name, barcode, or SKU...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              prodProvider.setSearchQuery('');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => prodProvider.setSearchQuery(val),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: Text('Low Stock (${prodProvider.lowStockProducts.length})'),
                      selected: _showOnlyLowStock,
                      selectedColor: AppTheme.danger.withAlpha(40),
                      labelStyle: TextStyle(
                        color: _showOnlyLowStock ? AppTheme.danger : AppTheme.textPrimary,
                        fontWeight: _showOnlyLowStock ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) => setState(() => _showOnlyLowStock = val),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: prodProvider.categories.map((c) {
                            final isSel = !_showOnlyLowStock && prodProvider.selectedCategory == c;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: isSel,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _showOnlyLowStock = false);
                                    prodProvider.setCategory(c);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: prodProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? Center(
                        child: Text(
                          _showOnlyLowStock
                              ? 'No low stock products right now!'
                              : 'No products found.\nTap "ADD PRODUCT" to create your first product.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final p = list[index];
                          return Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => AddEditProductScreen(product: p)),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: p.isLowStock
                                            ? AppTheme.danger.withAlpha(20)
                                            : AppTheme.primary.withAlpha(20),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2,
                                        color: p.isLowStock ? AppTheme.danger : AppTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${p.category} | SKU: ${p.sku.isNotEmpty ? p.sku : "-"} | VAT: ${p.gstRate}%',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                          ),
                                          if (p.barcode.isNotEmpty)
                                            Text(
                                              'Barcode: ${p.barcode}',
                                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          currency.format(p.sellingPrice),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: p.isLowStock
                                                ? AppTheme.danger.withAlpha(30)
                                                : AppTheme.success.withAlpha(30),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Stock: ${p.stockQuantity.toStringAsFixed(0)} ${p.unit}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: p.isLowStock ? AppTheme.danger : AppTheme.success,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.qr_code, color: AppTheme.textSecondary),
                                      tooltip: 'View Barcode',
                                      onPressed: () => _showBarcodeDialog(p),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
