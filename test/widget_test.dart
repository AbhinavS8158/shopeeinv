import 'package:flutter_test/flutter_test.dart';
import 'package:shopeeinv/core/models/product.dart';
import 'package:shopeeinv/core/models/invoice.dart';

void main() {
  test('Product model calculations and defaults', () {
    final product = Product(
      id: 'test-1',
      shopId: 'shop-1',
      name: 'Test Product',
      sellingPrice: 100.0,
      stockQuantity: 2.0,
      minStockAlert: 5.0,
      gstRate: 18.0,
    );

    expect(product.isLowStock, isTrue);
    expect(product.sellingPrice, 100.0);
    expect(product.gstRate, 18.0);
  });

  test('Invoice calculations validation', () {
    final item = InvoiceItem(
      productId: 'p-1',
      productName: 'Rice 1kg',
      quantity: 2.0,
      unitPrice: 50.0,
      taxAmount: 5.0,
      totalAmount: 105.0,
    );

    final invoice = Invoice(
      id: 'inv-1',
      shopId: 'shop-1',
      invoiceNumber: 'INV-20261029-001',
      items: [item],
      subtotal: 100.0,
      taxableAmount: 100.0,
      totalTax: 5.0,
      grandTotal: 105.0,
      paidAmount: 105.0,
    );

    expect(invoice.grandTotal, 105.0);
    expect(invoice.paymentStatus, 'paid');
    expect(invoice.items.length, 1);
  });
}
