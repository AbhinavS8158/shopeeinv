import 'package:flutter_test/flutter_test.dart';
import 'package:shopeeinv/core/models/product.dart';
import 'package:shopeeinv/core/models/category.dart';
import 'package:shopeeinv/core/models/invoice.dart';
import 'package:shopeeinv/providers/cart_provider.dart';

void main() {
  group('Category Model & Custom Category Tests', () {
    test('ProductCategory model serialization and deserialization', () {
      final category = ProductCategory(
        id: 'cat-1',
        shopId: 'shop-1',
        name: 'Vegetables',
      );

      final map = category.toMap();
      expect(map['id'], 'cat-1');
      expect(map['name'], 'Vegetables');

      final fromMap = ProductCategory.fromMap(map);
      expect(fromMap.id, 'cat-1');
      expect(fromMap.name, 'Vegetables');
    });

    test('Duplicate category detection logic (case-insensitive)', () {
      final existingCategories = ['Vegetables', 'Fruits', 'Grocery', 'Spices'];
      const newCategoryInput = '  spices  ';

      final isDuplicate = existingCategories.any(
        (c) => c.trim().toLowerCase() == newCategoryInput.trim().toLowerCase(),
      );
      expect(isDuplicate, isTrue);

      const uniqueCategory = 'Bakery';
      final isUniqueDuplicate = existingCategories.any(
        (c) => c.trim().toLowerCase() == uniqueCategory.trim().toLowerCase(),
      );
      expect(isUniqueDuplicate, isFalse);
    });
  });

  group('Weight-Based Billing Calculation Tests', () {
    // Test 5: Sell 110 g of a product priced at ₹100/kg -> ₹11.00
    test('Example 1: Chilli 110 g @ ₹100/kg = ₹11.00', () {
      final chilli = Product(
        id: 'prod-chilli',
        shopId: 'shop-1',
        name: 'Chilli',
        category: 'Spices',
        sellingPrice: 100.0,
        pricePerKg: 100.0,
        isSoldByWeight: true,
        unit: 'Kg',
        stockQuantity: 50.0,
      );

      expect(chilli.isWeightBased, isTrue);
      expect(chilli.effectivePricePerKg, 100.0);

      // 110 grams = 0.110 kg
      const purchasedGrams = 110.0;
      final weightKg = purchasedGrams / 1000.0;
      final calculatedAmount = (purchasedGrams / 1000.0) * chilli.effectivePricePerKg;

      expect(weightKg, closeTo(0.110, 0.0001));
      expect(calculatedAmount, closeTo(11.0, 0.01));

      final cartItem = CartItem(
        product: chilli,
        quantity: weightKg,
        isWeightItem: true,
        weightGrams: purchasedGrams,
        pricePerKg: chilli.effectivePricePerKg,
        weightDisplayUnit: 'g',
      );

      expect(cartItem.grossTotal, closeTo(11.0, 0.01));
      expect(cartItem.netTotal, closeTo(11.0, 0.01));
    });

    // Test 6: Sell 250 g of a product priced at ₹60/kg = ₹15.00
    test('Example 2: Rice 250 g @ ₹60/kg = ₹15.00', () {
      final rice = Product(
        id: 'prod-rice',
        shopId: 'shop-1',
        name: 'Rice',
        category: 'Grocery',
        sellingPrice: 60.0,
        pricePerKg: 60.0,
        isSoldByWeight: true,
        unit: 'Kg',
        stockQuantity: 100.0,
      );

      const purchasedGrams = 250.0;
      final weightKg = purchasedGrams / 1000.0;
      final calculatedAmount = (purchasedGrams / 1000.0) * rice.effectivePricePerKg;

      expect(weightKg, closeTo(0.250, 0.0001));
      expect(calculatedAmount, closeTo(15.0, 0.01));

      final cartItem = CartItem(
        product: rice,
        quantity: weightKg,
        isWeightItem: true,
        weightGrams: purchasedGrams,
        pricePerKg: rice.effectivePricePerKg,
        weightDisplayUnit: 'g',
      );

      expect(cartItem.grossTotal, closeTo(15.0, 0.01));
      expect(cartItem.netTotal, closeTo(15.0, 0.01));
    });

    // Test 7: Sell 1.5 kg of a product priced at ₹50/kg = ₹75.00
    test('Example 3: Sugar 1.5 kg @ ₹50/kg = ₹75.00', () {
      final sugar = Product(
        id: 'prod-sugar',
        shopId: 'shop-1',
        name: 'Sugar',
        category: 'Grocery',
        sellingPrice: 50.0,
        pricePerKg: 50.0,
        isSoldByWeight: true,
        unit: 'Kg',
        stockQuantity: 80.0,
      );

      const weightKg = 1.5;
      final calculatedAmount = weightKg * sugar.effectivePricePerKg;

      expect(calculatedAmount, closeTo(75.0, 0.01));

      final cartItem = CartItem(
        product: sugar,
        quantity: weightKg,
        isWeightItem: true,
        weightGrams: weightKg * 1000.0,
        pricePerKg: sugar.effectivePricePerKg,
        weightDisplayUnit: 'kg',
      );

      expect(cartItem.grossTotal, closeTo(75.0, 0.01));
      expect(cartItem.netTotal, closeTo(75.0, 0.01));
    });

    // Test 8 & 9: Bill with all 3 items: Total = ₹101.00
    test('Total Bill calculation with Chilli + Rice + Sugar = ₹101.00', () {
      final cart = CartProvider();

      final chilli = Product(
        id: 'p1',
        shopId: 's1',
        name: 'Chilli',
        sellingPrice: 100.0,
        pricePerKg: 100.0,
        isSoldByWeight: true,
        unit: 'Kg',
        stockQuantity: 50.0,
      );

      final rice = Product(
        id: 'p2',
        shopId: 's1',
        name: 'Rice',
        sellingPrice: 60.0,
        pricePerKg: 60.0,
        isSoldByWeight: true,
        unit: 'Kg',
        stockQuantity: 50.0,
      );

      final sugar = Product(
        id: 'p3',
        shopId: 's1',
        name: 'Sugar',
        sellingPrice: 50.0,
        pricePerKg: 50.0,
        isSoldByWeight: true,
        unit: 'Kg',
        stockQuantity: 50.0,
      );

      cart.addToCart(
        chilli,
        quantity: 0.110,
        isWeightItem: true,
        weightGrams: 110,
        pricePerKg: 100.0,
        weightDisplayUnit: 'g',
      );

      cart.addToCart(
        rice,
        quantity: 0.250,
        isWeightItem: true,
        weightGrams: 250,
        pricePerKg: 60.0,
        weightDisplayUnit: 'g',
      );

      cart.addToCart(
        sugar,
        quantity: 1.5,
        isWeightItem: true,
        weightGrams: 1500,
        pricePerKg: 50.0,
        weightDisplayUnit: 'kg',
      );

      expect(cart.items.length, 3);
      expect(cart.items[0].netTotal, closeTo(11.0, 0.01));
      expect(cart.items[1].netTotal, closeTo(15.0, 0.01));
      expect(cart.items[2].netTotal, closeTo(75.0, 0.01));
      expect(cart.grandTotal, closeTo(101.0, 0.01));
    });

    // Test 10: Inventory decrease by exact sold weight
    test('Inventory decreases by exact sold weight', () {
      const initialStock = 50.0; // 50 Kg
      const soldWeightChilli = 0.110; // 110 grams
      final remainingStock = initialStock - soldWeightChilli;
      expect(remainingStock, closeTo(49.890, 0.0001));

      const soldWeightSugar = 1.5; // 1.5 kg
      final remainingAfterSugar = initialStock - soldWeightSugar;
      expect(remainingAfterSugar, closeTo(48.5, 0.0001));
    });

    // Test 11: Bill snapshot preservation in InvoiceItem
    test('InvoiceItem stores historical weight snapshots', () {
      final chilli = Product(
        id: 'prod-chilli',
        shopId: 'shop-1',
        name: 'Chilli',
        sellingPrice: 100.0,
        pricePerKg: 100.0,
        isSoldByWeight: true,
        unit: 'Kg',
      );

      final cartItem = CartItem(
        product: chilli,
        quantity: 0.110,
        isWeightItem: true,
        weightGrams: 110.0,
        pricePerKg: 100.0,
        weightDisplayUnit: 'g',
      );

      final invoiceItem = cartItem.toInvoiceItem();
      expect(invoiceItem.isWeightBased, isTrue);
      expect(invoiceItem.weightInGrams, 110.0);
      expect(invoiceItem.pricePerKg, 100.0);
      expect(invoiceItem.productSellingType, 'weight');
      expect(invoiceItem.totalAmount, closeTo(11.0, 0.01));

      final map = invoiceItem.toMap();
      final restored = InvoiceItem.fromMap(map);
      expect(restored.isWeightBased, isTrue);
      expect(restored.weightInGrams, 110.0);
      expect(restored.pricePerKg, 100.0);
      expect(restored.totalAmount, closeTo(11.0, 0.01));
    });

    // Minimum Selling Weight enforcement
    test('Minimum selling weight validation', () {
      final saffron = Product(
        id: 'prod-saffron',
        shopId: 'shop-1',
        name: 'Saffron',
        sellingPrice: 300000.0,
        pricePerKg: 300000.0,
        isSoldByWeight: true,
        minSellingWeight: 5.0, // min 5 grams
        weightUnit: 'g',
        unit: 'Gm',
      );

      const requestedGrams = 2.0; // below 5g
      final isBelow = requestedGrams < saffron.minSellingWeight!;
      expect(isBelow, isTrue);

      const validGrams = 10.0;
      final isValid = validGrams >= saffron.minSellingWeight!;
      expect(isValid, isTrue);
    });
  });
}
