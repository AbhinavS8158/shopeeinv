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

  bool get isTaxIncluded => product.isTaxIncluded;

  double get unitPrice => customPrice;
  double get grossTotal => (unitPrice * quantity) - discountAmount;

  // Base taxable amount before tax
  double get taxableAmount {
    if (grossTotal <= 0) return 0.0;
    if (product.gstRate <= 0) return grossTotal;
    if (isTaxIncluded) {
      // Selling price already includes tax: extract base value
      return grossTotal / (1.0 + (product.gstRate / 100.0));
    } else {
      // Selling price excludes tax: base is the gross total
      return grossTotal;
    }
  }

  // Tax amount for this line
  double get taxAmount {
    if (grossTotal <= 0 || product.gstRate <= 0) return 0.0;
    if (isTaxIncluded) {
      // Tax included in price: extract tax amount
      return grossTotal - taxableAmount;
    } else {
      // Tax excluded from price: calculate on top of gross total
      return (grossTotal * product.gstRate) / 100.0;
    }
  }

  // Total amount payable for this item
  double get netTotal {
    if (isTaxIncluded) {
      // Already includes tax: do not add tax again!
      return grossTotal > 0 ? grossTotal : 0.0;
    } else {
      // Tax excluded: add tax to gross total
      return grossTotal + taxAmount;
    }
  }

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
    final baseTaxable = _items.fold(0.0, (sum, item) => sum + item.taxableAmount);
    final val = baseTaxable - _overallDiscount;
    return val > 0 ? val : 0.0;
  }

  double get totalTax {
    return _items.fold(0.0, (sum, item) => sum + item.taxAmount);
  }

  double get vatAmount => totalTax;
  double get cgstAmount => totalTax / 2.0;
  double get sgstAmount => totalTax / 2.0;

  double get rawGrandTotal {
    final total = _items.fold(0.0, (sum, item) => sum + item.netTotal) - _overallDiscount;
    return total > 0 ? total : 0.0;
  }

  double get roundOff {
    final rounded = rawGrandTotal.roundToDouble();
    return (rounded - rawGrandTotal);
  }

  double get grandTotal {
    final total = rawGrandTotal + roundOff;
    return total > 0 ? total : 0.0;
  }
}
