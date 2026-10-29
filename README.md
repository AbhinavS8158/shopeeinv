# ShopeeInv - Multi-Shop Billing & Inventory Management System 🛍️🧾

ഒരു സമ്പൂർണ്ണ **Multi-Shop Billing & Inventory Management System** (SaaS / Multi-Tenant Architecture). Flutter, SQLite (`sqflite`), Firebase എന്നിവ ഉപയോഗിച്ച് നിർമ്മിച്ച ഈ ആപ്ലിക്കേഷൻ **100% ഓഫ്‌ലൈനായും (Offline-First)** ഓൺലൈനായും (Cloud Sync) സുഗമമായി പ്രവർത്തിക്കുന്നു.

---

## 🌟 പ്രധാന സവിശേഷതകൾ (Key Features)

### 1. Multi-Shop / Multi-Tenant Architecture (മൾട്ടി-ഷോപ്പ് സംവിധാനം)
- ആപ്ലിക്കേഷനിൽ രജിസ്റ്റർ ചെയ്യുമ്പോൾ തന്നെ **Shop Setup / Business Profile** സ്ക്രീൻ വഴി പുതിയ ഷോപ്പ് ചേർക്കാം.
- ഷോപ്പിന്റെ പേര്, വിലാസം, ഫോൺ നമ്പർ, GSTIN, ലോഗോ, UPI ID, പ്രിന്റ് ഫോർമാറ്റ് എന്നിവ കസ്റ്റമൈസ് ചെയ്യാം.
- ഒന്നിലധികം ഷോപ്പുകളുള്ള ഉടമകൾക്ക് ഒരൊറ്റ ആപ്പിൽ നിന്ന് തന്നെ ഷോപ്പുകൾ മാറിമാറി (Switch Shop) കൈകാര്യം ചെയ്യാം.
- ഓരോ ഷോപ്പിലെയും പ്രൊഡക്ടുകൾ, സ്റ്റോക്ക്, ഉപഭോക്താക്കൾ, ബില്ലുകൾ എന്നിവ തികച്ചും സ്വതന്ത്രമായി (Isolated) സൂക്ഷിക്കപ്പെടുന്നു.

### 2. Offline-First & Firebase Cloud Sync (ഓഫ്‌ലൈൻ & ഓൺലൈൻ സിങ്ക്)
- **Local SQLite (`sqflite` & `sqflite_common_ffi`)**: ഇന്റർനെറ്റ് ഇല്ലാതെ തന്നെ അതിവേഗ ബില്ലിംഗ്, ബാർകോഡ് സ്കാനിംഗ്, സ്റ്റോക്ക് മാനേജ്മെന്റ്.
- **Firebase Firestore & Auth Sync**: ഇന്റർനെറ്റ് കണക്റ്റിവിറ്റി ലഭ്യമാകുമ്പോൾ തനിയെ ക്ലൗഡിലേക്ക് സിങ്ക് ചെയ്യപ്പെടുന്നു (`SyncService`).
- ഇന്റർനെറ്റ് തടസ്സപ്പെട്ടാലും ഒരു പ്രവർത്തനവും തടസ്സപ്പെടില്ല.

### 3. Core Modules (പ്രധാന മോഡ്യൂളുകൾ)

#### 📊 1. Dashboard
- ഇന്നത്തെ ആകെ വിൽപ്പന (Today's Sales & Bill Count)
- ഈ മാസത്തെ വിൽപ്പന സംഗ്രഹം (Monthly Sales)
- ആകെ പ്രൊഡക്റ്റുകൾ & Low Stock Alerts
- കസ്റ്റമർമാർ & അവരുടെ കുടിശ്ശിക (Total Customers & Udhar/Credit Balance)
- പെട്ടെന്നുള്ള ആക്ഷൻ ബട്ടണുകൾ (New Bill / POS, Add Product, Stock In, Invoices)
- Recent Invoices & ഒരു ക്ലിക്കിൽ Re-print സൗകര്യം.

#### 📦 2. Product Management
- പ്രൊഡക്റ്റിന്റെ പേര്, SKU, ബാർകോഡ് (Auto-generate or Scan)
- കാറ്റഗറി, പർച്ചേസ് വില, സെല്ലിംഗ് വില, MRP
- GST നിരക്കുകൾ (0%, 5%, 12%, 18%, 28%) & HSN/SAC കോഡ്
- സ്റ്റോക്ക് അളവ് (Stock Quantity), കുറഞ്ഞ സ്റ്റോക്ക് മുന്നറിയിപ്പ് പരിധി (Low-stock Alert Limit)
- അളവുകൾ (Units: Pcs, Kg, Gm, Ltr, Ml, Box, Meter, Packet etc.)
- സപ്ലയർ വിവരങ്ങൾ, എക്സ്പയറി തീയതി (Expiry Date)

#### 💻 3. Point of Sale (POS) & Fast Billing
- ബാർകോഡ് സ്കാനർ ഇൻപുട്ട് (കീബോർഡ് ബാർകോഡ് സ്കാനറോ ക്യാമറയോ ഉപയോഗിക്കാം)
- അതിവേഗ സെർച്ച് ബാറും കാറ്റഗറി ഫിൽട്ടറുകളും
- കാർട്ടിലേക്ക് പ്രൊഡക്റ്റുകൾ ചേർക്കൽ, അളവ് (+ / -) മാറ്റൽ
- ലൈൻ ഡിസ്കൗണ്ടും ഓവറോൾ ഡിസ്കൗണ്ടും
- GST ഓട്ടോമാറ്റിക് കണക്കുകൂട്ടൽ (CGST + SGST) & Round Off
- പേയ്‌മെന്റ് മോഡുകൾ: **Cash**, **UPI QR**, **Card**, **Credit (Udhar)**
- **ഡൈനാമിക് UPI QR Code**: ബിൽ തുകയോടെയുള്ള ഷോപ്പിന്റെ സ്വന്തം UPI QR കോഡ് സ്ക്രീനിൽ തന്നെ കാണിച്ച് കസ്റ്റമറിൽ നിന്ന് പണം സ്വീകരിക്കാം.

#### 🖨️ 4. Custom Invoice & Printing
- ഷോപ്പിന്റെ പേര്, GSTIN, ഫോൺ, വിലാസം എന്നിവയോടെയുള്ള ബില്ലുകൾ
- **A4 Full GST Tax Invoice**: എല്ലാ നിയമപ്രകാരമുള്ള GST വിവരങ്ങൾ, HSN കോഡുകൾ, ബാങ്ക്/UPI വിവരങ്ങൾ, ടേംസ് & കണ്ടീഷൻസ്, ഒപ്പ് രേഖപ്പെടുത്താനുള്ള സ്ഥലം എന്നിവ അടങ്ങിയത്.
- **Thermal Receipt (58mm & 80mm)**: POS തെർമൽ പ്രിന്ററുകൾക്കായി പ്രത്യേകം തയ്യാറാക്കിയ ഫോർമാറ്റ്.
- PDF ഡൗൺലോഡ് ചെയ്യാനും WhatsApp / ഇമെയിൽ വഴി ഷെയർ ചെയ്യാനുമുള്ള സൗകര്യം.

#### 📈 5. Inventory & Stock Management
- **Stock In / Purchase Entry**: പുതിയ സ്റ്റോക്ക് പർച്ചേസ് ചെയ്യുമ്പോൾ അളവ് വർദ്ധിപ്പിക്കൽ.
- ബില്ലിംഗ് നടക്കുമ്പോൾ **ഓട്ടോമാറ്റിക് സ്റ്റോക്ക് കുറയ്ക്കൽ (Auto Stock Deduction)**.
- **Stock Adjustment**: കേടുപാടുകൾ സംഭവിച്ചതോ (Damaged), കാലാവധി കഴിഞ്ഞതോ (Expired), നഷ്ടപ്പെട്ടതോ ആയ സ്റ്റോക്കുകൾ കാരണം സഹിതം ക്രമീകരിക്കാം.
- **Stock History / Audit Log**: ഓരോ പ്രൊഡക്റ്റിലും ഉണ്ടായ സ്റ്റോക്ക് വ്യതിയാനങ്ങളുടെ സമ്പൂർണ്ണ വിവരങ്ങൾ.

#### 👥 6. Customer & Udhar (Credit) Khata
- കസ്റ്റമർമാരുടെ വിവരങ്ങൾ (പേര്, ഫോൺ, GSTIN, വിലാസം).
- കുടിശ്ശിക (Credit / Udhar balance) ട്രാക്കിംഗ്.
- കുടിശ്ശിക തുക അടയ്ക്കുമ്പോൾ 'Collect Payment' വഴി അക്കൗണ്ട് അപ്‌ഡേറ്റ് ചെയ്യാം.

---

## 🚀 പ്രോജക്റ്റ് റൺ ചെയ്യുന്ന വിധം (How to Run)

### 1. ഡിപെൻഡൻസികൾ പരിശോധിക്കുക
```bash
flutter pub get
```

### 2. ആപ്ലിക്കേഷൻ റൺ ചെയ്യുക
- **Android ഡിവൈസിലോ എമുലേറ്ററിലോ**:
  ```bash
  flutter run -d android
  ```
- **Windows Desktop ആപ്പായി**:
  ```bash
  flutter run -d windows
  ```
- **Chrome ബ്രൗസറിൽ**:
  ```bash
  flutter run -d chrome
  ```

---

## 📁 പ്രോജക്റ്റ് ഫോൾഡർ ഘടന (Folder Structure)

```
lib/
├── core/
│   ├── database/
│   │   ├── app_database.dart       # SQLite Database (Mobile & Desktop)
│   │   └── sync_service.dart       # Firebase Cloud Sync Engine
│   ├── models/
│   │   ├── shop_profile.dart       # Multi-tenant Shop Profile model
│   │   ├── product.dart            # Product, SKU, Barcode, GST model
│   │   ├── customer.dart           # Customer & Udhar model
│   │   ├── invoice.dart            # Invoice & InvoiceItem model
│   │   └── stock_log.dart          # Stock In / Deduction Audit Log model
│   ├── services/
│   │   └── invoice_pdf_service.dart# A4 GST & Thermal (58/80mm) PDF Generator
│   └── theme/
│       └── app_theme.dart          # Modern POS UI Theme & Color Palette
├── providers/
│   ├── shop_provider.dart          # Multi-shop state & active shop switching
│   ├── product_provider.dart       # Product inventory state & CRUD
│   ├── cart_provider.dart          # POS cart & GST calculations
│   ├── billing_provider.dart       # Invoicing, stock decrement & sales stats
│   └── customer_provider.dart      # Customer & Udhar state
├── screens/
│   ├── auth/
│   │   └── shop_setup_screen.dart  # Business Profile & Onboarding Screen
│   ├── dashboard/
│   │   └── dashboard_screen.dart   # Main Dashboard with metrics & recent bills
│   ├── pos/
│   │   ├── pos_screen.dart         # Point of Sale Billing Screen
│   │   ├── invoice_preview_screen.dart # Interactive PDF Preview & Print
│   │   └── upi_payment_dialog.dart # Dynamic UPI QR Payment Dialog
│   ├── products/
│   │   ├── product_list_screen.dart# Product inventory list & barcodes
│   │   └── add_edit_product_screen.dart # Add / Edit Product form
│   ├── inventory/
│   │   └── stock_management_screen.dart # Stock In, Adjustments & Audit Logs
│   ├── invoices/
│   │   └── invoice_history_screen.dart  # Past Bills & Reprinting
│   ├── customers/
│   │   └── customer_list_screen.dart    # Customer Khata & Dues
│   └── settings/
│       └── shop_settings_screen.dart    # Multi-shop switcher & Cloud Sync
└── main.dart                       # Entry point with MultiProvider & Initializer
```
