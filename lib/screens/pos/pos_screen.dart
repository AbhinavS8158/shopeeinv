import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/customer.dart';
import '../../core/models/product.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/billing_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import 'invoice_preview_screen.dart';
import 'upi_payment_dialog.dart';
import 'cash_register_dialog.dart';
import '../../providers/cash_register_provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
      if (shop != null) {
        Provider.of<ProductProvider>(context, listen: false).loadProducts(shop.id);
        Provider.of<CustomerProvider>(context, listen: false).loadCustomers(shop.id);

        final cashProvider = Provider.of<CashRegisterProvider>(context, listen: false);
        await cashProvider.loadTodaySession(shop.id);
        if (!cashProvider.hasOpenSession && mounted) {
          final opened = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const CashRegisterDialog(),
          );
          if (opened != true && !cashProvider.hasOpenSession && mounted) {
            Navigator.pop(context);
          }
        }
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
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Added ${product.name} (+1)', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 700),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
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

      // Reload products right away so stock in memory is updated
      await Provider.of<ProductProvider>(context, listen: false).loadProducts(shop.id);

      if (!mounted) return;

      // Navigate to PDF Preview & Printing
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(shop: shop, invoice: invoice),
        ),
      );

      // When returning from DONE / NEW BILL, ensure products are reloaded and UI updated immediately
      if (mounted) {
        await Provider.of<ProductProvider>(context, listen: false).loadProducts(shop.id);
        setState(() {});
      }
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
            TextField(controller: gstinCtrl, decoration: const InputDecoration(labelText: 'VAT / TRN No. (Optional)')),
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
              final saved = await Provider.of<CustomerProvider>(context, listen: false).saveCustomer(customer);
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() => _selectedCustomer = saved ?? customer);
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
          TabBar(
            tabs: [
              const Tab(icon: Icon(Icons.grid_view), text: 'Products'),
              Consumer<CartProvider>(
                builder: (_, cart, __) => Tab(
                  icon: Badge.count(
                    count: cart.itemCount,
                    isLabelVisible: cart.itemCount > 0,
                    child: const Icon(Icons.shopping_cart),
                  ),
                  text: 'Cart & Bill',
                ),
              ),
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
    return Consumer2<ProductProvider, CartProvider>(
      builder: (ctx, prodProvider, cartProvider, _) {
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
            final cartIndex = cartProvider.items.indexWhere((item) => item.product.id == p.id);
            final inCartQty = cartIndex >= 0 ? cartProvider.items[cartIndex].quantity.toInt() : 0;

            return _AnimatedProductCard(
              product: p,
              inCartQty: inCartQty,
              currencyFormat: currencyFormat,
              onAdd: () {
                cartProvider.addToCart(p);
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Added ${p.name} (+1)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 650),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
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
                                    '${currencyFormat.format(item.unitPrice)} / ${item.product.unit} (VAT: ${item.product.gstRate}% ${item.isTaxIncluded ? "Incl." : "Excl."})',
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
                  _buildSummaryLine('VAT Amount', currencyFormat.format(cart.totalTax)),
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


class _AnimatedProductCard extends StatefulWidget {
  final Product product;
  final int inCartQty;
  final NumberFormat currencyFormat;
  final VoidCallback onAdd;

  const _AnimatedProductCard({
    required this.product,
    required this.inCartQty,
    required this.currencyFormat,
    required this.onAdd,
  });

  @override
  State<_AnimatedProductCard> createState() => _AnimatedProductCardState();
}

class _AnimatedProductCardState extends State<_AnimatedProductCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      lowerBound: 0.92,
      upperBound: 1.0,
    )..value = 1.0;
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    widget.onAdd();
    if (mounted) setState(() => _isAnimating = true);
    await _controller.reverse();
    if (mounted) {
      await _controller.forward();
    }
    await Future.delayed(const Duration(milliseconds: 320));
    if (mounted) {
      setState(() => _isAnimating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final hasInCart = widget.inCartQty > 0;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isAnimating
                ? AppTheme.success
                : (hasInCart ? AppTheme.primary.withAlpha(140) : Colors.transparent),
            width: _isAnimating ? 2.0 : (hasInCart ? 1.5 : 0.0),
          ),
          boxShadow: [
            BoxShadow(
              color: _isAnimating
                  ? AppTheme.success.withAlpha(60)
                  : (hasInCart ? AppTheme.primary.withAlpha(35) : Colors.black.withAlpha(12)),
              blurRadius: _isAnimating ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _handleTap,
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
                      if (hasInCart)
                        AnimatedScale(
                          scale: _isAnimating ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 160),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_bag, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  '${widget.inCartQty}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
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
                  if (p.imageBase64.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          base64Decode(p.imageBase64),
                          height: 38,
                          width: 38,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
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
                        widget.currencyFormat.format(p.sellingPrice),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _isAnimating ? AppTheme.success : AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _isAnimating ? Icons.check : Icons.add,
                            key: ValueKey(_isAnimating),
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
