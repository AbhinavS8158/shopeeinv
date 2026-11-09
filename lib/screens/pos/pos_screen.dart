import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../providers/combo_offer_provider.dart';

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
        Provider.of<ComboOfferProvider>(context, listen: false).loadComboOffers(shop.id);

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
      if (product.isWeightBased) {
        _barcodeInputController.clear();
        _showWeightInputDialog(product);
        return;
      }
      final inCartIdx = cartProvider.items.indexWhere((i) => i.product.id == product.id);
      final currentInCart = inCartIdx >= 0 ? cartProvider.items[inCartIdx].quantity : 0.0;
      if (currentInCart + 1 > product.stockQuantity) {
        _showOutOfStockDialog(product, requestedQty: currentInCart + 1);
        _barcodeInputController.clear();
        _barcodeFocusNode.requestFocus();
        return;
      }
      final activeOffers = Provider.of<ComboOfferProvider>(context, listen: false).activeOffers;
      cartProvider.addToCart(product, comboOffers: activeOffers);
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

  void _showWeightInputDialog(Product product, {CartItem? existingItem}) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final comboOffers = Provider.of<ComboOfferProvider>(context, listen: false).activeOffers;

    final inCartIdx = existingItem == null
        ? cart.items.indexWhere((i) => i.product.id == product.id)
        : -1;
    final CartItem? item = existingItem ?? (inCartIdx >= 0 ? cart.items[inCartIdx] : null);

    double initialWeightKg = item?.quantity ?? 1.0;
    String mode = (item?.weightDisplayUnit == 'g' || (item?.weightGrams != null && item!.weightGrams! < 1000))
        ? 'gm'
        : 'kg';

    final weightController = TextEditingController(
      text: mode == 'gm'
          ? (item?.weightGrams != null ? item!.weightGrams!.toStringAsFixed(0) : (initialWeightKg * 1000).toStringAsFixed(0))
          : (initialWeightKg % 1 == 0
              ? initialWeightKg.toInt().toString()
              : initialWeightKg.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final rawVal = double.tryParse(weightController.text.trim()) ?? 0.0;
          final finalWeightKg = mode == 'gm' ? (rawVal / 1000.0) : rawVal;
          final pricePerKg = product.effectivePricePerKg;
          // Formula: (Entered Weight in Grams / 1000) * Price Per Kilogram
          final estTotal = (mode == 'gm' ? (rawVal / 1000.0) : rawVal) * pricePerKg;
          final isExceedingStock = finalWeightKg > product.stockQuantity;

          final minWeightKg = (product.minSellingWeight != null && product.minSellingWeight! > 0)
              ? (product.weightUnit == 'g' ? (product.minSellingWeight! / 1000.0) : product.minSellingWeight!)
              : 0.0;
          final isBelowMin = rawVal > 0 && minWeightKg > 0 && finalWeightKg < minWeightKg;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.scale, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Price: ${currencyFormat.format(pricePerKg)} / kg',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Unit Toggle: Kg vs Gm
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (mode != 'kg') {
                                setDlgState(() {
                                  mode = 'kg';
                                  if (rawVal > 0) {
                                    final converted = rawVal / 1000.0;
                                    weightController.text = converted.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
                                  }
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: mode == 'kg' ? Colors.teal : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Kilograms (kg)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: mode == 'kg' ? Colors.white : Colors.blueGrey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (mode != 'gm') {
                                setDlgState(() {
                                  mode = 'gm';
                                  if (rawVal > 0) {
                                    final converted = (rawVal * 1000.0).round();
                                    weightController.text = converted.toString();
                                  }
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: mode == 'gm' ? Colors.teal : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Grams (g)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: mode == 'gm' ? Colors.white : Colors.blueGrey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Weight Input Box
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.teal),
                          decoration: InputDecoration(
                            labelText: mode == 'kg' ? 'Purchased Weight in Kilograms' : 'Purchased Weight in Grams',
                            hintText: mode == 'kg' ? 'e.g. 1.5' : 'e.g. 110 or 250',
                            prefixIcon: const Icon(Icons.scale, color: Colors.teal),
                            suffixText: mode == 'kg' ? 'kg' : 'g',
                            suffixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onChanged: (_) => setDlgState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined, color: Colors.blueGrey),
                        tooltip: 'Clear',
                        onPressed: () {
                          weightController.clear();
                          setDlgState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick Weight Preset Buttons
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Quick Weight Presets:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPresetChip('110g', () {
                        setDlgState(() {
                          mode = 'gm';
                          weightController.text = '110';
                        });
                      }),
                      _buildPresetChip('250g', () {
                        setDlgState(() {
                          mode = 'gm';
                          weightController.text = '250';
                        });
                      }),
                      _buildPresetChip('500g', () {
                        setDlgState(() {
                          mode = 'gm';
                          weightController.text = '500';
                        });
                      }),
                      _buildPresetChip('1 kg', () {
                        setDlgState(() {
                          mode = 'kg';
                          weightController.text = '1';
                        });
                      }),
                      _buildPresetChip('1.5 kg', () {
                        setDlgState(() {
                          mode = 'kg';
                          weightController.text = '1.5';
                        });
                      }),
                      _buildPresetChip('2 kg', () {
                        setDlgState(() {
                          mode = 'kg';
                          weightController.text = '2';
                        });
                      }),
                      _buildPresetChip('5 kg', () {
                        setDlgState(() {
                          mode = 'kg';
                          weightController.text = '5';
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Calculations Summary Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isExceedingStock
                          ? Colors.red.shade50
                          : (isBelowMin ? Colors.amber.shade50 : Colors.teal.shade50.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isExceedingStock
                            ? Colors.red.shade300
                            : (isBelowMin ? Colors.amber.shade400 : Colors.teal.shade200),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Formula:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            Text(
                              mode == 'gm'
                                  ? '(${rawVal.toStringAsFixed(0)}g / 1000) × ₹${pricePerKg.toStringAsFixed(0)}'
                                  : '${finalWeightKg.toStringAsFixed(3)}kg × ₹${pricePerKg.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Calculated Weight:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            Text(
                              mode == 'gm'
                                  ? '${rawVal.toStringAsFixed(0)} g (${finalWeightKg.toStringAsFixed(3)} kg)'
                                  : '${finalWeightKg.toStringAsFixed(3)} kg',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Calculated Amount:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(
                              currencyFormat.format(estTotal),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                            ),
                          ],
                        ),
                        if (isBelowMin) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.warning_amber, size: 14, color: Colors.orange),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Minimum selling weight is ${product.minSellingWeight} ${product.weightUnit}',
                                  style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (isExceedingStock) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Exceeds available stock (${product.stockQuantity} ${product.unit})',
                                  style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isExceedingStock || isBelowMin || finalWeightKg <= 0) ? Colors.grey : Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.check, size: 18, color: Colors.white),
                label: Text(
                  item != null ? 'Update Weight' : 'Add to Bill',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                onPressed: (isExceedingStock || isBelowMin || finalWeightKg <= 0)
                    ? (isExceedingStock ? () => _showOutOfStockDialog(product, requestedQty: finalWeightKg) : null)
                    : () {
                        final enteredGrams = mode == 'gm' ? rawVal : (rawVal * 1000.0);
                        final displayUnit = mode == 'gm' ? 'g' : 'kg';

                        if (item != null) {
                          cart.updateQuantity(
                            product.id,
                            finalWeightKg,
                            comboOffers: comboOffers,
                            weightGrams: enteredGrams,
                            weightDisplayUnit: displayUnit,
                          );
                        } else {
                          cart.addToCart(
                            product,
                            quantity: finalWeightKg,
                            comboOffers: comboOffers,
                            isWeightItem: true,
                            weightGrams: enteredGrams,
                            pricePerKg: pricePerKg,
                            weightDisplayUnit: displayUnit,
                          );
                        }
                        Navigator.pop(ctx);
                        final formattedWeight = mode == 'gm'
                            ? '${rawVal.toStringAsFixed(0)} g'
                            : '${finalWeightKg.toStringAsFixed(3).replaceAll(RegExp(r"0+$"), "").replaceAll(RegExp(r"\.$"), "")} kg';
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.scale, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Added ${product.name} ($formattedWeight @ ₹${pricePerKg.toStringAsFixed(0)}/kg = ${currencyFormat.format(estTotal)})'),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.teal,
                            duration: const Duration(milliseconds: 1500),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.teal.shade300),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
      ),
    );
  }

  void _showOutOfStockDialog(Product product, {double? requestedQty}) {
    final available = product.stockQuantity;
    final isCompletelyOut = available <= 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCompletelyOut ? Colors.red.shade50 : Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompletelyOut ? Icons.block : Icons.warning_amber_rounded,
                color: isCompletelyOut ? Colors.red.shade700 : Colors.amber.shade800,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isCompletelyOut ? 'Out of Stock!' : 'Insufficient Stock!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCompletelyOut ? Colors.red.shade800 : Colors.amber.shade900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Available Stock:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      Text(
                        '${available % 1 == 0 ? available.toInt() : available} ${product.unit}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isCompletelyOut ? Colors.red : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  if (requestedQty != null) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Requested Quantity:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        Text(
                          '${requestedQty % 1 == 0 ? requestedQty.toInt() : requestedQty} ${product.unit}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isCompletelyOut
                  ? 'This product is currently out of stock. Please add stock before billing.'
                  : 'Requested quantity exceeds the available inventory. You can only bill up to ${available.toInt()} ${product.unit}.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.3),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (!isCompletelyOut && requestedQty != null && requestedQty > available)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              onPressed: () {
                final cart = Provider.of<CartProvider>(context, listen: false);
                final comboOffers = Provider.of<ComboOfferProvider>(context, listen: false).activeOffers;
                cart.updateQuantity(product.id, available, comboOffers: comboOffers);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added maximum available stock (${available.toInt()} ${product.unit}) to cart.'),
                    backgroundColor: AppTheme.success,
                  ),
                );
              },
              child: Text('Add Max Available (${available.toInt()})'),
            ),
        ],
      ),
    );
  }

  void _showProductHoldMenu(Product product, int inCartQty) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final comboOffers = Provider.of<ComboOfferProvider>(context, listen: false).activeOffers;

    final existingIndex = cart.items.indexWhere((item) => item.product.id == product.id);
    double currentQty = existingIndex >= 0 ? cart.items[existingIndex].quantity : 1.0;
    final qtyController = TextEditingController(
      text: currentQty % 1 == 0 ? currentQty.toInt().toString() : currentQty.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final enteredQty = double.tryParse(qtyController.text.trim()) ?? 0.0;
          final currentUnitPrice = product.getUnitPriceForQty(enteredQty > 0 ? enteredQty : 1.0);
          final estTotal = currentUnitPrice * enteredQty;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.touch_app, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${currencyFormat.format(product.sellingPrice)} / ${product.unit}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existingIndex >= 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.shopping_cart, size: 16, color: Colors.green),
                            SizedBox(width: 6),
                            Text('Currently in Cart:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          '${currentQty % 1 == 0 ? currentQty.toInt() : currentQty} ${product.unit}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                  ),

                const Text(
                  'Manage Quantity',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),

                // Quantity +/- and Text Input row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Decrement button
                    Material(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          double q = double.tryParse(qtyController.text.trim()) ?? 1.0;
                          if (q > 1) {
                            q -= 1;
                            setDlgState(() {
                              qtyController.text = q % 1 == 0 ? q.toInt().toString() : q.toString();
                            });
                          }
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.remove, size: 22, color: AppTheme.primaryDark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Quantity Text Box
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          suffixText: product.unit,
                          suffixStyle: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        onChanged: (_) => setDlgState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Increment button
                    Material(
                      color: AppTheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          double q = double.tryParse(qtyController.text.trim()) ?? 0.0;
                          if (q + 1 > product.stockQuantity) {
                            _showOutOfStockDialog(product, requestedQty: q + 1);
                            return;
                          }
                          q += 1;
                          setDlgState(() {
                            qtyController.text = q % 1 == 0 ? q.toInt().toString() : q.toString();
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.add, size: 22, color: AppTheme.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Estimated line total
                Text(
                  'Item Total: ${currencyFormat.format(estTotal)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.scale, size: 16, color: Colors.teal),
                  label: const Text('Enter Custom Weight (Kg / Gm)',
                      style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showWeightInputDialog(product,
                        existingItem: existingIndex >= 0 ? cart.items[existingIndex] : null);
                  },
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Row(
                children: [
                  // If product is in cart, show "Deselect / Remove" button
                  if (existingIndex >= 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                          side: const BorderSide(color: AppTheme.danger),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.remove_shopping_cart, size: 18),
                        label: const Text('Deselect', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          cart.removeFromCart(product.id, comboOffers: comboOffers);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.remove_circle_outline, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Deselected ${product.name} from cart')),
                                ],
                              ),
                              backgroundColor: AppTheme.danger,
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                  const SizedBox(width: 10),
                  // Update / Apply Quantity button
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check, size: 18, color: Colors.white),
                      label: Text(
                        existingIndex >= 0 ? 'Update Qty' : 'Add to Cart',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: () {
                        final q = double.tryParse(qtyController.text.trim()) ?? 0.0;
                        if (q > product.stockQuantity) {
                          _showOutOfStockDialog(product, requestedQty: q);
                          return;
                        }
                        if (q <= 0) {
                          if (existingIndex >= 0) {
                            cart.removeFromCart(product.id, comboOffers: comboOffers);
                          }
                        } else {
                          if (existingIndex >= 0) {
                            cart.updateQuantity(product.id, q, comboOffers: comboOffers);
                          } else {
                            cart.addToCart(product, quantity: q, comboOffers: comboOffers);
                          }
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q <= 0
                                        ? 'Removed ${product.name} from cart'
                                        : 'Updated ${product.name} (${q % 1 == 0 ? q.toInt() : q} ${product.unit})',
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: AppTheme.success,
                            duration: const Duration(milliseconds: 900),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showItemDiscountDialog(CartItem item) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    String selectedType = item.isManualDiscount
        ? item.discountType
        : (item.discountType != 'none' ? item.discountType : 'percentage');
    final valCtrl = TextEditingController(
      text: item.discountValue > 0 ? item.discountValue.toString() : '',
    );
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('Apply Discount: ${item.product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price: ${currencyFormat.format(item.unitPrice)} | Qty: ${item.quantity.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Maximum allowed discount: ${item.product.maxDiscountPercent.toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Discount Type'),
                items: const [
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage (%)')),
                  DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount per unit (Rs.)')),
                  DropdownMenuItem(value: 'none', child: Text('Reset to Default / None')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setDlgState(() {
                      selectedType = v;
                      errorMessage = null;
                    });
                  }
                },
              ),
              if (selectedType != 'none') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: valCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: selectedType == 'percentage' ? 'Discount Percentage (%)' : 'Discount Amount (Rs.)',
                    prefixIcon: Icon(selectedType == 'percentage' ? Icons.percent : Icons.currency_rupee),
                    errorText: errorMessage,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final comboOffers = Provider.of<ComboOfferProvider>(context, listen: false).activeOffers;
                if (selectedType == 'none') {
                  cart.setItemDiscount(item.product.id, discountType: 'none', discountValue: 0.0);
                  cart.evaluateCombos(comboOffers);
                  Navigator.pop(ctx);
                  return;
                }

                final val = double.tryParse(valCtrl.text.trim()) ?? 0.0;
                final err = cart.setItemDiscount(
                  item.product.id,
                  discountType: selectedType,
                  discountValue: val,
                );
                if (err != null) {
                  setDlgState(() => errorMessage = err);
                } else {
                  cart.evaluateCombos(comboOffers);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvailableCombosModal() {
    final comboProvider = Provider.of<ComboOfferProvider>(context, listen: false);
    final activeOffers = comboProvider.activeOffers;
    final cart = Provider.of<CartProvider>(context, listen: false);
    final products = Provider.of<ProductProvider>(context, listen: false).products;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.local_offer, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text(
                      'Available Combo Offers',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            if (activeOffers.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No active combo offers configured.\nCreate combo offers from the Dashboard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: activeOffers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, index) {
                    final offer = activeOffers[index];
                    final isApplied = cart.activeCombos.any((c) => c.id == offer.id);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isApplied ? Colors.green.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isApplied ? Colors.green.shade400 : Colors.grey.shade300,
                          width: isApplied ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  offer.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              if (isApplied)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'APPLIED IN CART',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          if (offer.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(offer.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: offer.items.map((i) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  '${i.quantity.toInt()}x ${i.productName}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                offer.offerType == 'fixed_price'
                                    ? 'Special Price: Rs. ${offer.comboPrice.toStringAsFixed(2)}'
                                    : (offer.offerType == 'percentage_discount'
                                        ? '${offer.discountPercentage.toStringAsFixed(0)}% OFF Bundle'
                                        : 'Buy X Get Y Free'),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add_shopping_cart, size: 16),
                                label: const Text('Add Combo to Cart'),
                                style: ElevatedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: isApplied ? Colors.teal : AppTheme.primary,
                                ),
                                onPressed: () {
                                  for (final ci in offer.items) {
                                    final p = products.firstWhere(
                                      (prod) => prod.id == ci.productId,
                                      orElse: () => Product(id: '', shopId: '', name: '', sellingPrice: 0),
                                    );
                                    if (p.id.isNotEmpty && ci.quantity > p.stockQuantity) {
                                      _showOutOfStockDialog(p, requestedQty: ci.quantity);
                                      return;
                                    }
                                  }
                                  for (final ci in offer.items) {
                                    final p = products.firstWhere(
                                      (prod) => prod.id == ci.productId,
                                      orElse: () => Product(id: '', shopId: '', name: '', sellingPrice: 0),
                                    );
                                    if (p.id.isNotEmpty) {
                                      cart.addToCart(p, quantity: ci.quantity);
                                    }
                                  }
                                  cart.evaluateCombos(activeOffers);
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added "${offer.title}" to cart!'),
                                      backgroundColor: AppTheme.success,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
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
          Consumer<ComboOfferProvider>(
            builder: (_, comboProv, __) {
              final count = comboProv.activeOffers.length;
              return TextButton.icon(
                icon: Badge.count(
                  count: count,
                  isLabelVisible: count > 0,
                  backgroundColor: Colors.amber,
                  textColor: Colors.black87,
                  child: const Icon(Icons.local_offer_outlined, color: Colors.white),
                ),
                label: const Text('OFFERS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _showAvailableCombosModal,
              );
            },
          ),
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
              onHold: () => _showProductHoldMenu(p, inCartQty),
              onAdd: () {
                if (p.isWeightBased) {
                  _showWeightInputDialog(p);
                  return;
                }
                if (inCartQty + 1 > p.stockQuantity) {
                  _showOutOfStockDialog(p, requestedQty: (inCartQty + 1).toDouble());
                  return;
                }
                final activeOffers = Provider.of<ComboOfferProvider>(context, listen: false).activeOffers;
                cartProvider.addToCart(p, comboOffers: activeOffers);
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
                      final activeOffers = Provider.of<ComboOfferProvider>(context, listen: false).activeOffers;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              item.product.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () => _showWeightInputDialog(item.product, existingItem: item),
                                            borderRadius: BorderRadius.circular(4),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade50,
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: Colors.teal.shade300, width: 0.8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.scale, size: 10, color: Colors.teal),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    (item.product.isWeightBased || item.isWeightItem)
                                                        ? (item.weightDisplayUnit == 'g' || (item.weightGrams != null && item.weightGrams! < 1000)
                                                            ? '${(item.weightGrams ?? (item.quantity * 1000)).toStringAsFixed(0)} g'
                                                            : '${item.quantity.toStringAsFixed(3).replaceAll(RegExp(r"0+$"), "").replaceAll(RegExp(r"\.$"), "")} kg')
                                                        : '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(3).replaceAll(RegExp(r"0+$"), "").replaceAll(RegExp(r"\.$"), "")} ${item.product.unit}',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        (item.product.isWeightBased || item.isWeightItem)
                                            ? '₹${item.product.effectivePricePerKg.toStringAsFixed(0)}/kg (VAT: ${item.product.gstRate}% ${item.isTaxIncluded ? "Incl." : "Excl."})'
                                            : '${currencyFormat.format(item.unitPrice)} / ${item.product.unit} (VAT: ${item.product.gstRate}% ${item.isTaxIncluded ? "Incl." : "Excl."})',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                // Discount button
                                IconButton(
                                  icon: Icon(
                                    item.discountAmount > 0 ? Icons.local_offer : Icons.local_offer_outlined,
                                    size: 18,
                                    color: item.discountAmount > 0 ? Colors.orange : AppTheme.textSecondary,
                                  ),
                                  tooltip: 'Item Discount',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showItemDiscountDialog(item),
                                ),
                                const SizedBox(width: 6),
                                // Qty buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                      onPressed: () => cart.updateQuantity(item.product.id, item.quantity - 1, comboOffers: activeOffers),
                                    ),
                                    InkWell(
                                      onTap: () => _showWeightInputDialog(item.product, existingItem: item),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                                        child: Text(
                                          item.quantity % 1 == 0 ? item.quantity.toInt().toString() : item.quantity.toStringAsFixed(3).replaceAll(RegExp(r"0+$"), "").replaceAll(RegExp(r"\.$"), ""),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                      onPressed: () {
                                        if (item.quantity + 1 > item.product.stockQuantity) {
                                          _showOutOfStockDialog(item.product, requestedQty: item.quantity + 1);
                                          return;
                                        }
                                        cart.updateQuantity(item.product.id, item.quantity + 1, comboOffers: activeOffers);
                                      },
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
                                  onPressed: () => cart.removeFromCart(item.product.id, comboOffers: activeOffers),
                                ),
                              ],
                            ),
                            // Promotional badges row
                            if (item.appliedOfferTitle != null || item.discountAmount > 0 || item.isTierPricingApplied)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, left: 2),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: [
                                    if (item.appliedOfferTitle != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.green.shade300),
                                        ),
                                        child: Text(
                                          'Combo: ${item.appliedOfferTitle} (-${currencyFormat.format(item.discountAmount)})',
                                          style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    else if (item.discountAmount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.orange.shade300),
                                        ),
                                        child: Text(
                                          'Discount: -${currencyFormat.format(item.discountAmount)} (${item.discountType == "percentage" ? "${item.discountValue.toStringAsFixed(0)}%" : "Fixed"})',
                                          style: TextStyle(fontSize: 10, color: Colors.orange.shade900, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    if (item.isTierPricingApplied)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.indigo.shade300),
                                        ),
                                        child: Text(
                                          'Bulk Tier Price Applied',
                                          style: TextStyle(fontSize: 10, color: Colors.indigo.shade800, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
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
                if (cart.totalDiscount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount / Offer Savings',
                            style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                        Text('- ${currencyFormat.format(cart.totalDiscount)}',
                            style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                if (cart.activeCombos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Active Combo:',
                            style: TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold)),
                        Flexible(
                          child: Text(
                            cart.activeCombos.map((c) => c.title).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
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
  final VoidCallback onHold;

  const _AnimatedProductCard({
    required this.product,
    required this.inCartQty,
    required this.currencyFormat,
    required this.onAdd,
    required this.onHold,
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
            onLongPress: () {
              HapticFeedback.mediumImpact();
              widget.onHold();
            },
            onSecondaryTap: widget.onHold,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
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
                          if (p.isWeightBased) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.teal.shade200, width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.scale, size: 9, color: Colors.teal),
                                  SizedBox(width: 2),
                                  Text('Weight', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (hasInCart)
                        AnimatedScale(
                          scale: _isAnimating ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 160),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onHold();
                            },
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
                                  const SizedBox(width: 2),
                                  const Icon(Icons.more_vert, size: 10, color: Colors.white),
                                ],
                              ),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currencyFormat.format(p.sellingPrice),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                          if (p.discountType != 'none')
                            Text(
                              p.discountType == 'percentage'
                                  ? '${p.discountValue.toStringAsFixed(0)}% OFF'
                                  : '-Rs. ${p.discountValue.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            )
                          else if (p.quantityTiers.isNotEmpty)
                            const Text(
                              'Bulk Tier',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                        ],
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
