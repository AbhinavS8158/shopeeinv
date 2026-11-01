# ShopeeInv 🛍️🧾
### Multi-Shop Billing & Inventory Management System (Offline-First SaaS)

[![Flutter](https://img.shields.io/badge/Flutter-3.41+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/Local_DB-SQLite_(sqflite)-003B57?logo=sqlite&logoColor=white)](https://pub.dev/packages/sqflite)
[![Firebase](https://img.shields.io/badge/Cloud_Sync-Firebase_Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20Web-4CAF50)]()
[![License](https://img.shields.io/badge/License-MIT-blue.svg)]()

---

## 📌 Overview

**ShopeeInv** is a comprehensive, production-grade **Multi-Shop Billing and Inventory Management System** built with **Flutter**, **SQLite (`sqflite`)**, and **Firebase**. 

Rather than being tied to a single specific retail outlet, ShopeeInv is engineered as a customizable SaaS solution suitable for diverse businesses—including supermarkets, grocery stores, apparel outlets, electronics retailers, bakeries, and wholesale businesses.

The application features a **100% Offline-First architecture** using local SQLite for lightning-fast billing with zero latency, alongside an automated **Firebase Cloud Sync engine** that seamlessly replicates data across devices when an internet connection is available.

---

## 🏗️ System Architecture

```
                    ┌────────────────────────────────────────────────────────┐
                    │             ShopeeInv System Architecture              │
                    └───────────────────────────┬────────────────────────────┘
                                                │
         ┌──────────────────────────────────────┼──────────────────────────────────────┐
         ▼                                      ▼                                      ▼
   📱 Frontend (Flutter)               💾 Local DB (SQLite)                   ☁️ Cloud (Firebase)
   - Multi-Tenant Shop Isolation       - Zero-Latency POS Billing             - Cloud Firestore Collections
   - Reactive POS & Live Cart          - Instant Stock Decrements             - Multi-Device Synchronization
   - A4 GST & Thermal PDF Printing     - Offline Customer & Stock Logs        - Automatic Background Sync
   - Dynamic UPI QR Generation         - Cross-Platform (`sqflite_ffi`)       - Offline Conflict Resolution
```

---

## ✨ Key Features & Modules

### 1. 🏪 Multi-Shop / Multi-Tenant Isolation
- **Shop Setup & Profile Onboarding**: Automatically prompts new store owners upon first launch to configure their store profile:
  - Business Name & Owner Details
  - Contact Information (Phone, Email, Full Street Address, City, State, PIN)
  - **GSTIN Number** (formatted and verified for official tax invoices)
  - **Shop UPI ID** (for generating dynamic payment QR codes on screen and on printed bills)
  - Customizable Invoice Prefix (e.g., `INV-`)
  - Preferred Default Print Format (`A4`, `Thermal 58mm`, or `Thermal 80mm`)
  - Terms & Conditions / Receipt Footer Notes
- **Multi-Store Switching**: Manage multiple shops or branches from a single application. Easily toggle between stores with full data isolation for products, customers, stock, and bills.

### 2. ⚡ Offline-First Architecture & Cloud Sync
- **Local SQLite Storage (`sqflite` & `sqflite_common_ffi`)**: All operations—billing, inventory deduction, product edits, customer credit tracking—execute instantly in the local database with zero reliance on network availability.
- **Smart Cloud Synchronization (`SyncService`)**: Monitors network status (`connectivity_plus`) and automatically synchronizes unsynced local entities (`isSynced = 0`) with Firebase Firestore in the background.
- **Graceful Offline Degradation**: Runs smoothly whether offline or online without crashes or freezes.

### 3. 📊 Dashboard & Business Analytics
- **Today's Sales**: Real-time sales total (₹) and bill count for the current day.
- **Monthly Revenue**: Aggregate revenue metrics for the current calendar month.
- **Inventory Overview**: Total registered products and real-time **Low Stock Alert counter**.
- **Customer Khata Overview**: Total customers and total outstanding credit (Udhar) balance.
- **Quick Action Dock**: One-tap access to POS Billing, Product Catalog, Stock-In, and Invoices.
- **Recent Bills List**: Quick view of recent invoices with payment status badges and instant re-print shortcuts.

### 4. 📦 Product Management & Barcode Engine
- Product Name, Category, SKU, and **Barcode** support.
- **Built-in Barcode Generator**: Automatically generate 12-digit barcodes or assign existing supplier barcodes.
- Pricing structure: Purchase Price, Selling Price, and MRP.
- **GST Tax Slabs**: 0%, 5%, 12%, 18%, 28% with HSN/SAC code tracking.
- Units of Measurement: `Pcs`, `Kg`, `Gm`, `Ltr`, `Ml`, `Box`, `Meter`, `Packet`, `Set`.
- Stock tracking: Current stock levels with configurable **Low Stock Alert limits**.
- Supplier details and Expiry Date tracking.

### 5. 💻 Point of Sale (POS) & Fast Billing
- **Hardware Barcode Scanner Support**: Scan barcodes directly with USB/Bluetooth handheld barcode scanners to add items to the cart instantly.
- **Instant Product Search**: Real-time search by product name, SKU, or category filter chips.
- **Live Cart System**:
  - Quantity steppers (`+` / `-`) and unit-aware inputs.
  - Item-level discounts and overall bill discounts.
  - Automatic tax calculations: Subtotal, CGST, SGST, Round-Off, and Grand Total.
- **Payment Modes**:
  - **Cash** (with cash tendered calculation)
  - **UPI QR** (Instant payment collection)
  - **Card**
  - **Credit / Udhar** (Logs debt directly to customer's Khata)
- **Dynamic UPI Payment QR**: Displays a generated UPI QR code on screen containing the shop's UPI ID and the exact bill amount, allowing customers to scan and pay via Google Pay, PhonePe, Paytm, or any UPI app.

### 6. 🖨️ Custom Invoice & Receipt Printing
- **A4 Full GST Tax Invoice**: Compliant with GST guidelines—includes Seller GSTIN, Buyer Details, HSN table, CGST/SGST breakdown, Bank/UPI details, Terms & Conditions, and Authorized Signatory.
- **Thermal POS Receipt (58mm & 80mm)**: Optimized roll layout with centered business header, line items, tax breakdown, and bottom UPI payment QR.
- **Horizontally Scrollable Printer Selector**: Easily preview and toggle between formats without screen overflow.
- Direct printing to USB, Bluetooth, and network printers, plus PDF sharing via WhatsApp or email.

### 7. 📈 Inventory & Stock Audit Management
- **Stock-In / Purchase Entry**: Add incoming stock batches with supplier reference numbers and cost tracking.
- **Automatic Stock Decrement**: Deducts item stock in SQLite immediately upon invoice completion.
- **Stock Adjustment & Write-offs**: Adjust stock for damaged goods, expired products, physical audit discrepancies, or customer returns.
- **Stock Transaction History Log**: Detailed audit log recording every inventory change, change type, timestamp, and reference bill number.

### 8. 👥 Customer & Credit (Udhar) Khata
- Customer master database with phone numbers, addresses, and GSTIN.
- Real-time **Credit (Udhar) Balance Tracking**.
- **Collect Payment**: Record customer partial or full debt payments to update balances automatically.

---

## 📂 Project Directory Structure

```
c:\Users\abhin\SHOPEEINV\
├── lib\
│   ├── core\
│   │   ├── database\
│   │   │   ├── app_database.dart       # SQLite Database (Mobile & Desktop FFI)
│   │   │   └── sync_service.dart       # Background Firebase Sync Engine
│   │   ├── models\
│   │   │   ├── shop_profile.dart       # Multi-tenant Shop Profile model
│   │   │   ├── product.dart            # Product, SKU, Barcode, GST model
│   │   │   ├── customer.dart           # Customer & Udhar Credit model
│   │   │   ├── invoice.dart            # Invoice & InvoiceItem model
│   │   │   └── stock_log.dart          # Stock-in & Deduction Audit Log model
│   │   ├── services\
│   │   │   └── invoice_pdf_service.dart# A4 GST & Thermal (58/80mm) PDF Engine
│   │   └── theme\
│   │       └── app_theme.dart          # Modern POS Color Palette & Styling
│   ├── providers\
│   │   ├── shop_provider.dart          # Active Shop & Multi-Shop Switcher
│   │   ├── product_provider.dart       # Inventory CRUD & Stock Updates
│   │   ├── cart_provider.dart          # POS Cart Calculations & Taxes
│   │   ├── billing_provider.dart       # Invoicing, Sales Deductions & Stats
│   │   └── customer_provider.dart      # Customer Khata & Dues State
│   ├── screens\
│   │   ├── auth\
│   │   │   └── shop_setup_screen.dart  # Business Profile & Onboarding Screen
│   │   ├── dashboard\
│   │   │   └── dashboard_screen.dart   # Dashboard with Metrics & Recent Bills
│   │   ├── pos\
│   │   │   ├── pos_screen.dart         # Point of Sale Billing Screen
│   │   │   ├── invoice_preview_screen.dart # Interactive PDF Preview & Print
│   │   │   └── upi_payment_dialog.dart # Dynamic UPI QR Payment Modal
│   │   ├── products\
│   │   │   ├── product_list_screen.dart# Product Inventory & Barcode Views
│   │   │   └── add_edit_product_screen.dart # Product Add/Edit Form
│   │   ├── inventory\
│   │   │   └── stock_management_screen.dart # Stock In, Adjustments & Audit
│   │   ├── invoices\
│   │   │   └── invoice_history_screen.dart  # Sales Invoices & Reprinting
│   │   ├── customers\
│   │   │   └── customer_list_screen.dart    # Customer List & Udhar Collection
│   │   └── settings\
│   │       └── shop_settings_screen.dart    # Multi-Shop Switcher & Cloud Sync
│   └── main.dart                       # App Entry Point & Initializer
├── test\
│   └── widget_test.dart                # Unit & Calculation Tests
└── pubspec.yaml                        # Dependencies Configuration
```

---

## 🛠️ Technology Stack & Dependencies

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Frontend Framework** | [Flutter 3.41+](https://flutter.dev) | Cross-platform UI toolkit |
| **Language** | [Dart 3.11+](https://dart.dev) | Modern client-optimized language |
| **State Management** | [Provider](https://pub.dev/packages/provider) | Clean, reactive state management |
| **Local Database** | [sqflite](https://pub.dev/packages/sqflite) & [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi) | SQLite engine for mobile and desktop |
| **Cloud Database** | [cloud_firestore](https://pub.dev/packages/cloud_firestore) | Real-time Firebase cloud database |
| **Document Generation** | [pdf](https://pub.dev/packages/pdf) | Pure Dart PDF document generator |
| **Hardware Printing** | [printing](https://pub.dev/packages/printing) | Native print dialogs & rasterization |
| **Barcode & QR** | [barcode_widget](https://pub.dev/packages/barcode_widget) & [qr_flutter](https://pub.dev/packages/qr_flutter) | High-resolution barcode and UPI QR rendering |
| **Connectivity** | [connectivity_plus](https://pub.dev/packages/connectivity_plus) | Network state detection |

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.30+ recommended)
- Android Studio / VS Code with Flutter extension
- Android Device / Emulator or Windows PC

### 2. Clone and Install Dependencies
```bash
# Navigate to project directory
cd c:\Users\abhin\SHOPEEINV

# Fetch all packages
flutter pub get
```

### 3. Run Unit Tests
Ensure models and business calculation logic are validated:
```bash
flutter test
```

### 4. Launch Application

#### On Android Device:
```bash
flutter run -d android
# Or specify a device ID:
flutter run -d <device_id>
```

#### On Windows Desktop:
```bash
flutter run -d windows
```

#### In Google Chrome:
```bash
flutter run -d chrome
```

---

## ☁️ Firebase Cloud Sync Setup (Optional)

The system works out-of-the-box in **100% offline mode** using local SQLite. To enable multi-device cloud synchronization via Firebase:

1. Create a project in the [Firebase Console](https://console.firebase.google.com/).
2. Register an Android application with package name `com.shopeeinv.shopeeinv`.
3. Download `google-services.json` and place it in the `android/app/` folder.
4. Enable **Cloud Firestore** in test mode or with appropriate security rules.
5. In the app, navigate to **Settings -> Offline Database & Cloud Sync -> Sync Now**. The system will push local records and synchronize data seamlessly.

---

## 📄 License
This project is licensed under the MIT License.
