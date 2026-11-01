import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('shopeeinv.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Desktop initialization (Windows, Linux, macOS)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final docDir = await getApplicationDocumentsDirectory();
      final path = join(docDir.path, 'ShopeeInv', filePath);
      
      // Ensure directory exists
      final dir = Directory(dirname(path));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
        ),
      );
    } else {
      // Mobile initialization (Android, iOS)
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(
        path,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    }
  }

  Future _createDB(Database db, int version) async {
    // 1. Shops Table
    await db.execute('''
      CREATE TABLE shops (
        id TEXT PRIMARY KEY,
        ownerId TEXT NOT NULL,
        shopName TEXT NOT NULL,
        ownerName TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT,
        gstin TEXT,
        address TEXT NOT NULL,
        city TEXT,
        state TEXT,
        pincode TEXT,
        upiId TEXT,
        logoBase64 TEXT,
        invoicePrefix TEXT DEFAULT 'INV-',
        defaultInvoiceType TEXT DEFAULT 'a4',
        termsAndConditions TEXT,
        isTaxInclusive INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // 2. Products Table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        shopId TEXT NOT NULL,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        category TEXT,
        purchasePrice REAL DEFAULT 0.0,
        sellingPrice REAL NOT NULL,
        mrp REAL,
        gstRate REAL DEFAULT 0.0,
        stockQuantity REAL DEFAULT 0.0,
        minStockAlert REAL DEFAULT 5.0,
        unit TEXT DEFAULT 'Pcs',
        hsnCode TEXT,
        supplierName TEXT,
        expiryDate TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0,
        isDeleted INTEGER DEFAULT 0
      )
    ''');

    // 3. Customers Table
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        shopId TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        gstin TEXT,
        creditBalance REAL DEFAULT 0.0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // 4. Invoices Table
    await db.execute('''
      CREATE TABLE invoices (
        id TEXT PRIMARY KEY,
        shopId TEXT NOT NULL,
        invoiceNumber TEXT NOT NULL,
        invoiceDate TEXT NOT NULL,
        customerId TEXT,
        customerName TEXT,
        customerPhone TEXT,
        customerGstin TEXT,
        itemsJson TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discountAmount REAL DEFAULT 0.0,
        taxableAmount REAL NOT NULL,
        cgstAmount REAL DEFAULT 0.0,
        sgstAmount REAL DEFAULT 0.0,
        igstAmount REAL DEFAULT 0.0,
        totalTax REAL NOT NULL,
        roundOff REAL DEFAULT 0.0,
        grandTotal REAL NOT NULL,
        paidAmount REAL NOT NULL,
        dueAmount REAL DEFAULT 0.0,
        paymentMode TEXT NOT NULL,
        paymentStatus TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // 5. Stock Logs Table
    await db.execute('''
      CREATE TABLE stock_logs (
        id TEXT PRIMARY KEY,
        shopId TEXT NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        changeType TEXT NOT NULL,
        quantityChange REAL NOT NULL,
        previousQuantity REAL NOT NULL,
        newQuantity REAL NOT NULL,
        reason TEXT,
        referenceId TEXT,
        createdAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // Indices for ultra-fast POS search and queries
    await db.execute('CREATE INDEX idx_products_shop ON products(shopId)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_invoices_shop ON invoices(shopId)');
    await db.execute('CREATE INDEX idx_customers_shop ON customers(shopId)');

    // 6. Cash Register Sessions Table
    await db.execute('''
      CREATE TABLE cash_register_sessions (
        id TEXT PRIMARY KEY,
        shopId TEXT NOT NULL,
        date TEXT NOT NULL,
        openingAmount REAL NOT NULL,
        openedAt TEXT NOT NULL,
        closingAmount REAL,
        closedAt TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        notes TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_cash_sessions_shop_date ON cash_register_sessions(shopId, date)');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cash_register_sessions (
          id TEXT PRIMARY KEY,
          shopId TEXT NOT NULL,
          date TEXT NOT NULL,
          openingAmount REAL NOT NULL,
          openedAt TEXT NOT NULL,
          closingAmount REAL,
          closedAt TEXT,
          status TEXT NOT NULL DEFAULT 'open',
          notes TEXT,
          isSynced INTEGER DEFAULT 0
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cash_sessions_shop_date ON cash_register_sessions(shopId, date)');
    }
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
