import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/database/app_database.dart';
import '../../core/models/product.dart';
import '../../core/models/stock_log.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  List<StockLog> _stockLogs = [];
  bool _isLoadingLogs = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoadingLogs = true);
    final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
    if (shop != null) {
      final db = await AppDatabase.instance.database;
      final res = await db.query(
        'stock_logs',
        where: 'shopId = ?',
        whereArgs: [shop.id],
        orderBy: 'createdAt DESC',
        limit: 100,
      );
      setState(() {
        _stockLogs = res.map((m) => StockLog.fromMap(m)).toList();
        _isLoadingLogs = false;
      });
    } else {
      setState(() => _isLoadingLogs = false);
    }
  }

  void _showStockInDialog() {
    final products = Provider.of<ProductProvider>(context, listen: false).products;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add products first before stock-in.')),
      );
      return;
    }

    Product selectedProduct = products.first;
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Purchase Stock In');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Stock In / Purchase Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Product:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<Product>(
                isExpanded: true,
                value: selectedProduct,
                items: products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (Cur: ${p.stockQuantity})'))).toList(),
                onChanged: (p) {
                  if (p != null) setDialogState(() => selectedProduct = p);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Incoming Quantity *', prefixIcon: Icon(Icons.add_box)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Note / Supplier Bill No', prefixIcon: Icon(Icons.description)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                if (qty <= 0) return;
                final shop = Provider.of<ShopProvider>(context, listen: false).currentShop!;
                await Provider.of<ProductProvider>(context, listen: false).adjustStock(
                  shopId: shop.id,
                  productId: selectedProduct.id,
                  newQuantity: selectedProduct.stockQuantity + qty,
                  reason: reasonCtrl.text.trim(),
                  changeType: 'purchase',
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadLogs();
              },
              child: const Text('Add Stock'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStockAdjustmentDialog() {
    final products = Provider.of<ProductProvider>(context, listen: false).products;
    if (products.isEmpty) return;

    Product selectedProduct = products.first;
    final newQtyCtrl = TextEditingController(text: selectedProduct.stockQuantity.toString());
    String reasonType = 'Damaged / Expired';
    final customReasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Stock Adjustment / Write-off'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Product:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<Product>(
                isExpanded: true,
                value: selectedProduct,
                items: products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (Cur: ${p.stockQuantity})'))).toList(),
                onChanged: (p) {
                  if (p != null) {
                    setDialogState(() {
                      selectedProduct = p;
                      newQtyCtrl.text = p.stockQuantity.toString();
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newQtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'New Corrected Stock Quantity *', prefixIcon: Icon(Icons.edit)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: reasonType,
                decoration: const InputDecoration(labelText: 'Adjustment Reason'),
                items: const [
                  DropdownMenuItem(value: 'Damaged / Expired', child: Text('Damaged / Expired')),
                  DropdownMenuItem(value: 'Physical Inventory Audit', child: Text('Physical Inventory Audit')),
                  DropdownMenuItem(value: 'Customer Return', child: Text('Customer Return')),
                  DropdownMenuItem(value: 'Lost / Theft', child: Text('Lost / Theft')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => reasonType = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: customReasonCtrl,
                decoration: const InputDecoration(labelText: 'Additional Notes (Optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
              onPressed: () async {
                final newQty = double.tryParse(newQtyCtrl.text.trim());
                if (newQty == null) return;
                final shop = Provider.of<ShopProvider>(context, listen: false).currentShop!;
                final fullReason = customReasonCtrl.text.trim().isNotEmpty
                    ? '$reasonType: ${customReasonCtrl.text.trim()}'
                    : reasonType;

                await Provider.of<ProductProvider>(context, listen: false).adjustStock(
                  shopId: shop.id,
                  productId: selectedProduct.id,
                  newQuantity: newQty,
                  reason: fullReason,
                  changeType: 'adjustment',
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadLogs();
              },
              child: const Text('Update Stock'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prodProvider = Provider.of<ProductProvider>(context);
    final lowStock = prodProvider.lowStockProducts;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory & Stock Management'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.inventory), text: 'Stock Overview'),
              Tab(icon: Icon(Icons.history), text: 'Stock History Log'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Overview & Actions
            Column(
              children: [
                // Quick Action Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('STOCK IN (PURCHASE)'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                          onPressed: _showStockInDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.tune),
                          label: const Text('STOCK ADJUSTMENT'),
                          onPressed: _showStockAdjustmentDialog,
                        ),
                      ),
                    ],
                  ),
                ),

                // Low Stock Alert Banner if any
                if (lowStock.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.danger.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: AppTheme.danger),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Alert: ${lowStock.length} items are running below minimum stock limit!',
                            style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Product Stock Table
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: prodProvider.products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, index) {
                      final p = prodProvider.products[index];
                      return Card(
                        child: ListTile(
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Category: ${p.category} | Alert at: ${p.minStockAlert.toStringAsFixed(0)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${p.stockQuantity.toStringAsFixed(0)} ${p.unit}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: p.isLowStock ? AppTheme.danger : AppTheme.success,
                                ),
                              ),
                              if (p.isLowStock)
                                const Text(
                                  'LOW STOCK',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.danger),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Tab 2: Stock Logs
            _isLoadingLogs
                ? const Center(child: CircularProgressIndicator())
                : _stockLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No stock movement history yet.\nSales and stock-ins will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _stockLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (ctx, index) {
                          final log = _stockLogs[index];
                          final isPositive = log.quantityChange > 0;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPositive
                                    ? AppTheme.success.withAlpha(30)
                                    : AppTheme.danger.withAlpha(30),
                                child: Icon(
                                  isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isPositive ? AppTheme.success : AppTheme.danger,
                                ),
                              ),
                              title: Text(log.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '${DateFormat('dd/MM/yy hh:mm a').format(log.createdAt)}\n${log.reason.isNotEmpty ? log.reason : log.changeType.toUpperCase()}',
                              ),
                              isThreeLine: true,
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isPositive ? "+" : ""}${log.quantityChange.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isPositive ? AppTheme.success : AppTheme.danger,
                                    ),
                                  ),
                                  Text('Bal: ${log.newQuantity.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
