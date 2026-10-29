import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/customer.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/billing_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import 'invoice_preview_screen.dart';
import 'upi_payment_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _barcodeInputController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();

  Customer? _selectedCustomer;
  String _paymentMode = 'cash'; // 'cash', 'upi', 'card', 'credit'
  bool _isProcessing = false;

  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
      if (shop != null) {
        Provider.of<ProductProvider>(context, listen: false).loadProducts(shop.id);
        Provider.of<CustomerProvider>(context, listen: false).loadCustomers(shop.id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _barcodeInputController.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  void _onBarcodeSubmitted(String barcode) {
    if (barcode.trim().isEmpty) return;
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    final product = productProvider.findByBarcode(barcode.trim());
    if (product != null) {
      cartProvider.addToCart(product);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${product.name} to cart'),
          duration: const Duration(milliseconds: 700),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product with barcode "$barcode" not found'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
    _barcodeInputController.clear();
    _barcodeFocusNode.requestFocus();
  }

  Future<void> _processCheckout() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
    final billing = Provider.of<BillingProvider>(context, listen: false);

    if (shop == null) return;
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty! Add products first.')),
      );
      return;
    }

    if (_paymentMode == 'upi' && shop.upiId.isNotEmpty) {
      final nextInvNum = await billing.getNextInvoiceNumber(shop.id, shop.invoicePrefix);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => UpiPaymentDialog(
          shop: shop,
          amount: cart.grandTotal,
          billNumber: nextInvNum,
          onPaymentConfirmed: () {
            _finalizeBill(paidAmount: cart.grandTotal);
          },
        ),
      );
      return;
    }

    _finalizeBill(paidAmount: _paymentMode == 'credit' ? 0.0 : cart.grandTotal);
  }

  Future<void> _finalizeBill({required double paidAmount}) async {
    setState(() => _isProcessing = true);

    final cart = Provider.of<CartProvider>(context, listen: false);
    final shop = Provider.of<ShopProvider>(context, listen: false).currentShop!;
    final billing = Provider.of<BillingProvider>(context, listen: false);

    final invoiceNumber = await billing.getNextInvoiceNumber(shop.id, shop.invoicePrefix);

    final invoice = await billing.createInvoice(
      shopId: shop.id,
      invoiceNumber: invoiceNumber,
      customerId: _selectedCustomer?.id ?? '',
      customerName: _selectedCustomer?.name ?? 'Walk-in Customer',
      customerPhone: _selectedCustomer?.phone ?? '',
      customerGstin: _selectedCustomer?.gstin ?? '',
      cartItems: List.from(cart.items),
      subtotal: cart.subtotal,
      discountAmount: cart.totalDiscount,
      taxableAmount: cart.taxableAmount,
      cgstAmount: cart.cgstAmount,
      sgstAmount: cart.sgstAmount,
      totalTax: cart.totalTax,
      roundOff: cart.roundOff,
      grandTotal: cart.grandTotal,
      paidAmount: paidAmount,
      paymentMode: _paymentMode,
    );

    setState(() => _isProcessing = false);

    if (invoice != null && mounted) {
      cart.clearCart();
      setState(() {
        _selectedCustomer = null;
        _paymentMode = 'cash';
      });

      // Navigate to PDF Preview & Printing
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(shop: shop, invoice: invoice),
        ),
      );
    }
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
            const SizedBox(height: 12),
            TextField(controller: gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN (Optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final shop = Provider.of<ShopProvider>(context, listen: false).currentShop!;
              final customer = Customer(
                id: const Uuid().v4(),
                shopId: shop.id,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                gstin: gstinCtrl.text.trim().toUpperCase(),
              );
              await Provider.of<CustomerProvider>(context, listen: false).saveCustomer(customer);
              setState(() => _selectedCustomer = customer);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Customer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Billing'),
        actions: [
          Consumer<CartProvider>(
            builder: (_, cart, __) => TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              label: const Text('CLEAR CART', style: TextStyle(color: Colors.white)),
              onPressed: cart.isEmpty ? null : () => cart.clearCart(),
            ),
          ),
        ],
      ),
      body: isWide ? _buildWideLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left Column: Catalog & Search
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildSearchBarAndBarcode(),
              _buildCategorySelector(),
              Expanded(child: _buildProductGrid()),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // Right Column: Live Cart & Checkout
        Expanded(
          flex: 4,
          child: _buildCartSection(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.grid_view), text: 'Products'),
              Tab(icon: Icon(Icons.shopping_cart), text: 'Cart & Bill'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                Column(
                  children: [
                    _buildSearchBarAndBarcode(),
                    _buildCategorySelector(),
                    Expanded(child: _buildProductGrid()),
                  ],
                ),
                _buildCartSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarAndBarcode() {
    final prodProvider = Provider.of<ProductProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          // Text Search
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search product by name or SKU...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          prodProvider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) => prodProvider.setSearchQuery(val),
            ),
          ),
          const SizedBox(width: 10),
          // Barcode Quick Scan Input
          Expanded(
            flex: 2,
            child: TextField(
              controller: _barcodeInputController,
              focusNode: _barcodeFocusNode,
              decoration: const InputDecoration(
                hintText: 'Scan Barcode',
                prefixIcon: Icon(Icons.qr_code_scanner),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onSubmitted: _onBarcodeSubmitted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Consumer<ProductProvider>(
      builder: (_, prodProvider, __) {
        final categories = prodProvider.categories;
        return Container(
          height: 48,
          color: Colors.white,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, index) {
              final cat = categories[index];
              final isSelected = cat == prodProvider.selectedCategory;
              return FilterChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: AppTheme.primaryLight.withAlpha(40),
                checkmarkColor: AppTheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => prodProvider.setCategory(cat),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductGrid() {
    return Consumer<ProductProvider>(
      builder: (ctx, prodProvider, _) {
        if (prodProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = prodProvider.filteredProducts;

        if (products.isEmpty) {
          return const Center(
            child: Text(
              'No products found.\nAdd products from the Products screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 1.1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            return Card(
              elevation: 1.5,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Provider.of<CartProvider>(context, listen: false).addToCart(p);
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              p.category,
                              style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            'Stock: ${p.stockQuantity.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: p.isLowStock ? AppTheme.danger : AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currencyFormat.format(p.sellingPrice),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartSection() {
    final cart = Provider.of<CartProvider>(context);
    final customers = Provider.of<CustomerProvider>(context).customers;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Customer selection row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Customer?>(
                      isExpanded: true,
                      value: _selectedCustomer,
                      hint: const Row(
                        children: [
                          Icon(Icons.person_outline, size: 20, color: AppTheme.textSecondary),
                          SizedBox(width: 8),
                          Text('Walk-in Customer', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                      items: [
                        const DropdownMenuItem<Customer?>(
                          value: null,
                          child: Text('Walk-in Customer (General)'),
                        ),
                        ...customers.map(
                          (c) => DropdownMenuItem<Customer?>(
                            value: c,
                            child: Text('${c.name} (${c.phone.isNotEmpty ? c.phone : "No Ph"})'),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _selectedCustomer = val),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.person_add, color: AppTheme.primary),
                  tooltip: 'Add New Customer',
                  onPressed: _showAddCustomerDialog,
                ),
              ],
            ),
          ),

          // Cart Items List
          Expanded(
            child: cart.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 56, color: AppTheme.border),
                        SizedBox(height: 10),
                        Text('Cart is empty', style: TextStyle(color: AppTheme.textSecondary)),
                        Text('Click products or scan barcode', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, index) {
                      final item = cart.items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '${currencyFormat.format(item.unitPrice)} / ${item.product.unit} (GST: ${item.product.gstRate}%)',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            // Qty buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () => cart.updateQuantity(item.product.id, item.quantity - 1),
                                ),
                                Text(
                                  '${item.quantity.toStringAsFixed(0)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: () => cart.updateQuantity(item.product.id, item.quantity + 1),
                                ),
                              ],
                            ),
                            // Item Total
                            SizedBox(
                              width: 80,
                              child: Text(
                                currencyFormat.format(item.netTotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
                              onPressed: () => cart.removeFromCart(item.product.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Cart Totals and Payment Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: const Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                _buildSummaryLine('Subtotal', currencyFormat.format(cart.subtotal)),
                if (cart.totalTax > 0)
                  _buildSummaryLine('GST (CGST + SGST)', currencyFormat.format(cart.totalTax)),
                if (cart.roundOff != 0)
                  _buildSummaryLine('Round Off', cart.roundOff.toStringAsFixed(2)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('GRAND TOTAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      currencyFormat.format(cart.grandTotal),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Payment Mode Selection
                Row(
                  children: [
                    _buildPaymentModeChip('cash', 'Cash', Icons.money),
                    const SizedBox(width: 6),
                    _buildPaymentModeChip('upi', 'UPI QR', Icons.qr_code_2),
                    const SizedBox(width: 6),
                    _buildPaymentModeChip('card', 'Card', Icons.credit_card),
                    const SizedBox(width: 6),
                    _buildPaymentModeChip('credit', 'Udhar', Icons.account_balance_wallet),
                  ],
                ),
                const SizedBox(height: 10),

                // Checkout Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.receipt_long),
                    label: Text(
                      _paymentMode == 'credit' ? 'SAVE AS UDHAR (CREDIT)' : 'CHARGE ${currencyFormat.format(cart.grandTotal)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _paymentMode == 'credit' ? AppTheme.warning : AppTheme.success,
                    ),
                    onPressed: _isProcessing || cart.isEmpty ? null : _processCheckout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeChip(String mode, String label, IconData icon) {
    final isSelected = _paymentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _paymentMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : AppTheme.textSecondary),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
