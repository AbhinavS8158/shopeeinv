import 'package:flutter/material.dart';
import '../core/models/combo_offer.dart';
import '../core/models/invoice.dart';
import '../core/models/product.dart';

class CartItem {
  final Product product;
  double quantity;
  double customPrice;
  double discountAmount; // Line discount in currency
  String discountType; // 'none', 'percentage', 'fixed'
  double discountValue; // The rate, e.g. 10 for 10% or 50 for Rs. 50
  bool isManualDiscount;
  bool isManualPrice;
  String? appliedOfferTitle;

  CartItem({
    required this.product,
    this.quantity = 1.0,
    double? customPrice,
    this.discountAmount = 0.0,
    this.discountType = 'none',
    this.discountValue = 0.0,
    this.isManualDiscount = false,
    this.isManualPrice = false,
    this.appliedOfferTitle,
  }) : customPrice = customPrice ?? product.getUnitPriceForQty(quantity) {
    if (!isManualDiscount) {
      applyDefaultDiscount();
    }
  }

  void recalculatePricing() {
    if (!isManualPrice) {
      customPrice = product.getUnitPriceForQty(quantity);
    }
    if (isManualDiscount) {
      if (discountType == 'percentage') {
        discountAmount = (customPrice * quantity) * (discountValue / 100.0);
      } else if (discountType == 'fixed') {
        discountAmount = discountValue * quantity;
      }
    } else if (appliedOfferTitle == null) {
      applyDefaultDiscount();
    }
  }

  void applyDefaultDiscount() {
    discountType = product.discountType;
    discountValue = product.discountValue;
    discountAmount = product.calculateDefaultDiscount(customPrice, quantity);
  }

  bool get isTierPricingApplied => !isManualPrice && customPrice != product.sellingPrice;

  bool get isTaxIncluded => product.isTaxIncluded;

  double get unitPrice => customPrice;
  double get grossTotal {
    final val = (unitPrice * quantity) - discountAmount;
    return val > 0 ? val : 0.0;
  }

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
      return grossTotal;
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
  final List<ComboOffer> _activeCombos = [];

  List<CartItem> get items => _items;
  double get overallDiscount => _overallDiscount;
  bool get isTaxInclusive => _isTaxInclusive;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.length;
  List<ComboOffer> get activeCombos => _activeCombos;

  void setTaxInclusive(bool value) {
    _isTaxInclusive = value;
    notifyListeners();
  }

  /// Returns null on success, or an error message if out of stock
  String? addToCart(Product product, {double quantity = 1.0, List<ComboOffer>? comboOffers, bool enforceStock = true}) {
    final index = _items.indexWhere((i) => i.product.id == product.id);
    final currentQty = index >= 0 ? _items[index].quantity : 0.0;
    final targetQty = currentQty + quantity;

    if (enforceStock && product.stockQuantity <= 0) {
      return 'Out of Stock! "${product.name}" has 0 stock available.';
    }
    if (enforceStock && targetQty > product.stockQuantity) {
      return 'Insufficient Stock! Only ${product.stockQuantity.toInt()} ${product.unit} available.';
    }

    if (index >= 0) {
      _items[index].quantity = targetQty;
      _items[index].recalculatePricing();
    } else {
      _items.add(CartItem(product: product, quantity: targetQty));
    }
    if (comboOffers != null) {
      evaluateCombos(comboOffers);
    }
    notifyListeners();
    return null;
  }

  /// Returns null on success, or an error message if out of stock
  String? updateQuantity(String productId, double quantity, {List<ComboOffer>? comboOffers, bool enforceStock = true}) {
    if (quantity <= 0) {
      removeFromCart(productId, comboOffers: comboOffers);
      return null;
    }
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      final product = _items[index].product;
      if (enforceStock && quantity > product.stockQuantity) {
        return 'Insufficient Stock! Only ${product.stockQuantity.toInt()} ${product.unit} available.';
      }
      _items[index].quantity = quantity;
      _items[index].recalculatePricing();
      if (comboOffers != null) {
        evaluateCombos(comboOffers);
      }
      notifyListeners();
      return null;
    }
    return 'Product not found in cart';
  }

  String? setItemDiscount(String productId, {required String discountType, required double discountValue}) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index < 0) return 'Product not found in cart';

    final item = _items[index];
    if (discountType == 'percentage') {
      if (discountValue < 0) return 'Discount cannot be negative';
      if (discountValue > item.product.maxDiscountPercent) {
        return 'Exceeds maximum allowed discount of ${item.product.maxDiscountPercent.toStringAsFixed(0)}%';
      }
      item.discountType = 'percentage';
      item.discountValue = discountValue;
      item.discountAmount = (item.unitPrice * item.quantity) * (discountValue / 100.0);
      item.isManualDiscount = true;
      item.appliedOfferTitle = null;
    } else if (discountType == 'fixed') {
      final maxAllowedFixed = item.unitPrice * (item.product.maxDiscountPercent / 100.0);
      if (discountValue < 0) return 'Discount cannot be negative';
      if (discountValue > maxAllowedFixed) {
        return 'Exceeds maximum allowed limit of Rs. ${maxAllowedFixed.toStringAsFixed(2)} (${item.product.maxDiscountPercent.toStringAsFixed(0)}%)';
      }
      item.discountType = 'fixed';
      item.discountValue = discountValue;
      item.discountAmount = discountValue * item.quantity;
      item.isManualDiscount = true;
      item.appliedOfferTitle = null;
    } else {
      item.isManualDiscount = false;
      item.appliedOfferTitle = null;
      item.applyDefaultDiscount();
    }

    notifyListeners();
    return null; // success
  }

  void setCustomPrice(String productId, double price) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      _items[index].customPrice = price;
      _items[index].isManualPrice = true;
      _items[index].recalculatePricing();
      notifyListeners();
    }
  }

  void setOverallDiscount(double discount) {
    _overallDiscount = discount;
    notifyListeners();
  }

  void removeFromCart(String productId, {List<ComboOffer>? comboOffers}) {
    _items.removeWhere((i) => i.product.id == productId);
    if (comboOffers != null) {
      evaluateCombos(comboOffers);
    }
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _overallDiscount = 0.0;
    _activeCombos.clear();
    notifyListeners();
  }

  // Auto-evaluate Combo Offers
  void evaluateCombos(List<ComboOffer> availableOffers) {
    _activeCombos.clear();

    // Reset applied combo titles on items not having manual discount
    for (final item in _items) {
      if (!item.isManualDiscount && item.appliedOfferTitle != null) {
        item.appliedOfferTitle = null;
        item.applyDefaultDiscount();
      }
    }

    for (final offer in availableOffers) {
      if (!offer.isValidNow) continue;

      // Check if all items in combo are present with required quantities
      bool matches = true;
      double normalSubtotal = 0.0;

      for (final comboItem in offer.items) {
        final found = _items.firstWhere(
          (cartItem) => cartItem.product.id == comboItem.productId,
          orElse: () => CartItem(product: Product(id: '', shopId: '', name: '', sellingPrice: 0)),
        );
        if (found.product.id.isEmpty || found.quantity < comboItem.quantity) {
          matches = false;
          break;
        }
        normalSubtotal += found.unitPrice * comboItem.quantity;
      }

      if (matches && normalSubtotal > 0) {
        _activeCombos.add(offer);

        // Calculate discount
        double comboSavings = 0.0;
        if (offer.offerType == 'fixed_price' && offer.comboPrice < normalSubtotal) {
          comboSavings = normalSubtotal - offer.comboPrice;
        } else if (offer.offerType == 'percentage_discount' && offer.discountPercentage > 0) {
          comboSavings = normalSubtotal * (offer.discountPercentage / 100.0);
        }

        if (comboSavings > 0) {
          // Proportionally distribute combo discount across participating items
          for (final comboItem in offer.items) {
            final cartItem = _items.firstWhere((i) => i.product.id == comboItem.productId);
            if (!cartItem.isManualDiscount) {
              final lineNormal = cartItem.unitPrice * comboItem.quantity;
              final lineShare = comboSavings * (lineNormal / normalSubtotal);
              cartItem.discountAmount = lineShare;
              cartItem.appliedOfferTitle = offer.title;
            }
          }
        }
      }
    }
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
