import 'package:flutter/material.dart';
import '../core/models/invoice.dart';
import '../core/models/product.dart';

class CartItem {
  final Product product;
  double quantity;
  double customPrice;
  double discountAmount; // Line discount

  CartItem({
    required this.product,
    this.quantity = 1.0,
    double? customPrice,
    this.discountAmount = 0.0,
  }) : customPrice = customPrice ?? product.sellingPrice;

  double get unitPrice => customPrice;
  double get grossTotal => (unitPrice * quantity) - discountAmount;

  // Tax calculation
  double get taxAmount {
    if (product.gstRate <= 0) return 0.0;
    // Assuming selling price is exclusive of tax by default
    return (grossTotal * product.gstRate) / 100.0;
  }

  double get netTotal => grossTotal + taxAmount;

  InvoiceItem toInvoiceItem() {
    return InvoiceItem(
      productId: product.id,
      productName: product.name,
      quantity: quantity,
      unit: product.unit,
      unitPrice: unitPrice,
      discountAmount: discountAmount,
      gstRate: product.gstRate,
      taxAmount: taxAmount,
      totalAmount: netTotal,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  double _overallDiscount = 0.0;
  bool _isTaxInclusive = false;

  List<CartItem> get items => _items;
  double get overallDiscount => _overallDiscount;
  bool get isTaxInclusive => _isTaxInclusive;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.length;

  void setTaxInclusive(bool value) {
    _isTaxInclusive = value;
    notifyListeners();
  }

  void addToCart(Product product, {double quantity = 1.0}) {
    final index = _items.indexWhere((i) => i.product.id == product.id);
    if (index >= 0) {
      _items[index].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      _items[index].quantity = quantity;
      notifyListeners();
    }
  }

  void setLineDiscount(String productId, double discount) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      _items[index].discountAmount = discount;
      notifyListeners();
    }
  }

  void setCustomPrice(String productId, double price) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      _items[index].customPrice = price;
      notifyListeners();
    }
  }

  void setOverallDiscount(double discount) {
    _overallDiscount = discount;
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _items.removeWhere((i) => i.product.id == productId);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _overallDiscount = 0.0;
    notifyListeners();
  }

  // Financial calculations
  double get subtotal {
    return _items.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
  }

  double get totalLineDiscount {
    return _items.fold(0.0, (sum, item) => sum + item.discountAmount);
  }

  double get totalDiscount => totalLineDiscount + _overallDiscount;

  double get taxableAmount {
    final val = subtotal - totalDiscount;
    return val > 0 ? val : 0.0;
  }

  double get totalTax {
    return _items.fold(0.0, (sum, item) => sum + item.taxAmount);
  }

  double get cgstAmount => totalTax / 2.0;
  double get sgstAmount => totalTax / 2.0;

  double get rawGrandTotal => taxableAmount + totalTax;

  double get roundOff {
    final rounded = rawGrandTotal.roundToDouble();
    return (rounded - rawGrandTotal);
  }

  double get grandTotal {
    final total = rawGrandTotal + roundOff;
    return total > 0 ? total : 0.0;
  }
}
