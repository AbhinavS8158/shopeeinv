import 'package:flutter_test/flutter_test.dart';
import 'package:shopeeinv/core/models/product.dart';
import 'package:shopeeinv/core/models/combo_offer.dart';
import 'package:shopeeinv/providers/cart_provider.dart';

void main() {
  group('ComboOffer Model & Serialization Tests', () {
    test('Buy X Get Y Free serialization and deserialization', () {
      final offer = ComboOffer(
        id: 'promo-bogo-1',
        shopId: 'shop-1',
        title: 'Buy 1 Colgate Get 1 Free',
        description: 'Get a free Colgate toothpaste with every purchase',
        offerType: 'buy_x_get_y',
        items: [ComboItem(productId: 'colgate-1', productName: 'Colgate', quantity: 1.0)],
        buyQuantity: 1.0,
        freeProductId: 'colgate-1',
        freeProductName: 'Colgate',
        freeQuantity: 1.0,
        isActive: true,
      );

      expect(offer.isBuyXGetY, isTrue);
      expect(offer.isQuantitySpecialPrice, isFalse);

      final map = offer.toMap();
      expect(map['offerType'], 'buy_x_get_y');
      expect(map['buyQuantity'], 1.0);
      expect(map['freeProductId'], 'colgate-1');
      expect(map['freeQuantity'], 1.0);

      final fromMap = ComboOffer.fromMap(map);
      expect(fromMap.id, 'promo-bogo-1');
      expect(fromMap.isBuyXGetY, isTrue);
      expect(fromMap.freeProductName, 'Colgate');
      expect(fromMap.freeQuantity, 1.0);
    });

    test('Quantity-Based Special Price serialization and deserialization', () {
      final offer = ComboOffer(
        id: 'promo-sugar-special',
        shopId: 'shop-1',
        title: 'Sugar 5kg Wholesale Deal',
        description: 'Buy 5 kg sugar at promotional price ₹250',
        offerType: 'quantity_special_price',
        items: [ComboItem(productId: 'sugar-1', productName: 'Sugar', quantity: 5.0)],
        minPurchaseQty: 5.0,
        specialPrice: 250.0,
        isActive: true,
      );

      expect(offer.isQuantitySpecialPrice, isTrue);
      expect(offer.isBuyXGetY, isFalse);

      final map = offer.toMap();
      expect(map['offerType'], 'quantity_special_price');
      expect(map['minPurchaseQty'], 5.0);
      expect(map['specialPrice'], 250.0);

      final fromMap = ComboOffer.fromMap(map);
      expect(fromMap.id, 'promo-sugar-special');
      expect(fromMap.minPurchaseQty, 5.0);
      expect(fromMap.specialPrice, 250.0);
    });
  });

  group('Buy X Get Y Free POS Cart Integration Tests', () {
    final colgate = Product(
      id: 'colgate-1',
      shopId: 'shop-1',
      name: 'Colgate Toothpaste 100g',
      sellingPrice: 80.0,
      stockQuantity: 100.0,
      unit: 'Pcs',
    );

    final shampoo = Product(
      id: 'shampoo-1',
      shopId: 'shop-1',
      name: 'Dove Shampoo 200ml',
      sellingPrice: 190.0,
      stockQuantity: 50.0,
      unit: 'Pcs',
    );

    final conditioner = Product(
      id: 'conditioner-1',
      shopId: 'shop-1',
      name: 'Dove Conditioner 180ml',
      sellingPrice: 175.0,
      stockQuantity: 50.0,
      unit: 'Pcs',
    );

    test('Same Product: Buy 1 Colgate Get 1 Free auto-adds free item with 100% discount', () {
      final cart = CartProvider();
      final allProducts = [colgate, shampoo, conditioner];

      final bogoOffer = ComboOffer(
        id: 'offer-bogo-colgate',
        shopId: 'shop-1',
        title: 'Buy 1 Get 1 Free',
        offerType: 'buy_x_get_y',
        items: [ComboItem(productId: colgate.id, productName: colgate.name, quantity: 1.0)],
        buyQuantity: 1.0,
        freeProductId: colgate.id,
        freeProductName: colgate.name,
        freeQuantity: 1.0,
        isActive: true,
      );

      // Add 1 Colgate to cart
      cart.addToCart(colgate, quantity: 1.0, comboOffers: [bogoOffer], allProducts: allProducts);

      // Cart should now contain 2 line items: 1 paid Colgate + 1 free promotional Colgate
      expect(cart.items.length, 2);
      final paidItem = cart.items.firstWhere((i) => !i.isFreePromoItem);
      final freeItem = cart.items.firstWhere((i) => i.isFreePromoItem);

      expect(paidItem.product.id, colgate.id);
      expect(paidItem.quantity, 1.0);
      expect(paidItem.netTotal, 80.0);

      expect(freeItem.product.id, colgate.id);
      expect(freeItem.quantity, 1.0);
      expect(freeItem.isFreePromoItem, isTrue);
      expect(freeItem.discountAmount, 80.0);
      expect(freeItem.netTotal, 0.0);

      // Total payable should be only ₹80 (customer gets 2 items, pays for 1)
      expect(cart.grandTotal, 80.0);
    });

    test('Proportional Multiples: Buy 2 Colgate Get 2 Free', () {
      final cart = CartProvider();
      final allProducts = [colgate];

      final bogoOffer = ComboOffer(
        id: 'offer-bogo-colgate',
        shopId: 'shop-1',
        title: 'Buy 1 Get 1 Free',
        offerType: 'buy_x_get_y',
        items: [ComboItem(productId: colgate.id, productName: colgate.name, quantity: 1.0)],
        buyQuantity: 1.0,
        freeProductId: colgate.id,
        freeProductName: colgate.name,
        freeQuantity: 1.0,
        isActive: true,
      );

      // Buy 2 Colgate
      cart.addToCart(colgate, quantity: 2.0, comboOffers: [bogoOffer], allProducts: allProducts);

      expect(cart.items.length, 2);
      final freeItem = cart.items.firstWhere((i) => i.isFreePromoItem);
      expect(freeItem.quantity, 2.0);
      expect(freeItem.netTotal, 0.0);
      expect(cart.grandTotal, 160.0); // 2 * 80
    });

    test('Auto-removal: If qualifying product is removed, free item is removed automatically', () {
      final cart = CartProvider();
      final allProducts = [colgate];

      final bogoOffer = ComboOffer(
        id: 'offer-bogo-colgate',
        shopId: 'shop-1',
        title: 'Buy 1 Get 1 Free',
        offerType: 'buy_x_get_y',
        items: [ComboItem(productId: colgate.id, productName: colgate.name, quantity: 1.0)],
        buyQuantity: 1.0,
        freeProductId: colgate.id,
        freeProductName: colgate.name,
        freeQuantity: 1.0,
        isActive: true,
      );

      cart.addToCart(colgate, quantity: 1.0, comboOffers: [bogoOffer], allProducts: allProducts);
      expect(cart.items.length, 2);

      // Remove paid product
      cart.removeFromCart(colgate.id, comboOffers: [bogoOffer], allProducts: allProducts);

      // Entire cart should now be empty (free item cleaned up)
      expect(cart.items.isEmpty, isTrue);
      expect(cart.grandTotal, 0.0);
    });

    test('Different Product: Buy 1 Shampoo Get 1 Conditioner Free', () {
      final cart = CartProvider();
      final allProducts = [shampoo, conditioner];

      final crossOffer = ComboOffer(
        id: 'offer-shampoo-conditioner',
        shopId: 'shop-1',
        title: 'Buy Shampoo Get Conditioner Free',
        offerType: 'buy_x_get_y',
        items: [ComboItem(productId: shampoo.id, productName: shampoo.name, quantity: 1.0)],
        buyQuantity: 1.0,
        freeProductId: conditioner.id,
        freeProductName: conditioner.name,
        freeQuantity: 1.0,
        isActive: true,
      );

      cart.addToCart(shampoo, quantity: 1.0, comboOffers: [crossOffer], allProducts: allProducts);

      expect(cart.items.length, 2);
      final freeItem = cart.items.firstWhere((i) => i.isFreePromoItem);
      expect(freeItem.product.id, conditioner.id);
      expect(freeItem.quantity, 1.0);
      expect(freeItem.netTotal, 0.0);
      expect(cart.grandTotal, 190.0); // Only pays for shampoo
    });
  });

  group('Quantity-Based Special Pricing Tests', () {
    final sugar = Product(
      id: 'sugar-1',
      shopId: 'shop-1',
      name: 'Sugar Premium',
      sellingPrice: 60.0,
      pricePerKg: 60.0,
      isSoldByWeight: true,
      unit: 'Kg',
      stockQuantity: 500.0,
    );

    final sugarSpecialOffer = ComboOffer(
      id: 'offer-sugar-bulk',
      shopId: 'shop-1',
      title: 'Sugar 5kg Special Offer',
      offerType: 'quantity_special_price',
      items: [ComboItem(productId: sugar.id, productName: sugar.name, quantity: 5.0)],
      minPurchaseQty: 5.0,
      specialPrice: 250.0, // Regular price is 5 * 60 = 300; special price is 250 (savings 50)
      isActive: true,
    );

    test('Customer purchases 5 kg: promotional price is ₹250 instead of ₹300', () {
      final cart = CartProvider();

      cart.addToCart(
        sugar,
        quantity: 5.0,
        comboOffers: [sugarSpecialOffer],
        allProducts: [sugar],
      );

      expect(cart.items.length, 1);
      final item = cart.items.first;
      expect(item.quantity, 5.0);
      expect(item.unitPrice, 60.0);
      // Savings = (5 * 60) - 250 = 50.0
      expect(item.discountAmount, 50.0);
      expect(item.netTotal, 250.0);
      expect(cart.grandTotal, 250.0);
    });

    test('Customer purchases 6 kg: 1 slab @ ₹250 + 1 kg @ ₹60 = ₹310', () {
      final cart = CartProvider();

      cart.addToCart(
        sugar,
        quantity: 6.0,
        comboOffers: [sugarSpecialOffer],
        allProducts: [sugar],
      );

      expect(cart.items.length, 1);
      final item = cart.items.first;
      expect(item.quantity, 6.0);
      // Normal subtotal = 6 * 60 = 360. Discount for 1 slab = 50. Total = 310.
      expect(item.discountAmount, 50.0);
      expect(item.netTotal, 310.0);
      expect(cart.grandTotal, 310.0);
    });

    test('Customer purchases 10 kg: 2 slabs @ ₹250 = ₹500', () {
      final cart = CartProvider();

      cart.addToCart(
        sugar,
        quantity: 10.0,
        comboOffers: [sugarSpecialOffer],
        allProducts: [sugar],
      );

      final item = cart.items.first;
      // Normal subtotal = 10 * 60 = 600. Discount for 2 slabs = 2 * 50 = 100. Total = 500.
      expect(item.discountAmount, 100.0);
      expect(item.netTotal, 500.0);
      expect(cart.grandTotal, 500.0);
    });

    test('Quantity drops below 5 kg (e.g. 4 kg): Reverts to regular selling price (4 * 60 = ₹240)', () {
      final cart = CartProvider();

      // Start with 5 kg (eligible)
      cart.addToCart(sugar, quantity: 5.0, comboOffers: [sugarSpecialOffer], allProducts: [sugar]);
      expect(cart.grandTotal, 250.0);

      // Reduce to 4 kg (ineligible)
      cart.updateQuantity(sugar.id, 4.0, comboOffers: [sugarSpecialOffer], allProducts: [sugar]);

      final item = cart.items.first;
      expect(item.quantity, 4.0);
      expect(item.discountAmount, 0.0);
      expect(item.netTotal, 240.0);
      expect(cart.grandTotal, 240.0);
    });
  });

  group('Invoice Snapshot & Inventory Deductions', () {
    test('Free promo item snapshots correctly with totalAmount 0.0 and free_promo type', () {
      final item = CartItem(
        product: Product(
          id: 'gift-1',
          shopId: 's1',
          name: 'Free Mug',
          sellingPrice: 150.0,
          unit: 'Pcs',
        ),
        quantity: 1.0,
        isFreePromoItem: true,
      );

      final invoiceItem = item.toInvoiceItem();
      expect(invoiceItem.productId, 'gift-1');
      expect(invoiceItem.productName, contains('[FREE]'));
      expect(invoiceItem.totalAmount, 0.0);
      expect(invoiceItem.discountAmount, 150.0);
      expect(invoiceItem.productSellingType, 'free_promo');
    });
  });
}
