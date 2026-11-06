# ShopeeInv – Flutter Web Admin Panel & License Management System

A centralized, responsive **Flutter Web** administrative dashboard and software licensing engine designed for **ShopeeInv POS & Inventory System**.

This system implements the exact specifications and architecture from the design blueprint ([ChatGPT Reference Specification](https://chatgpt.com/s/t_6aed9b94f5c881919ef3891d2bc7dd44)), fully replacing any legacy Node.js admin implementations with a pure Flutter client & cloud architecture.

---

## 🌟 Key Features

### 1. Executive Dashboard & Metrics
- **Real-Time KPIs**: Total Registered Users, Active Licenses, Expired Licenses, Total Registered Hardware Devices, and Available Device Slots.
- **Interactive Visualizations**:
  - 7-Day Device Connection Traffic (fl_chart LineChart).
  - License Distribution by Status (fl_chart PieChart: Active, Expired, Suspended, Revoked).
- **Recent Activity Timelines**: Live feeds of recent customer registrations and license activations.

### 2. Customer & Shop Management
- Full CRUD for business accounts (Shop Name, Owner Name, Email, Phone, Address, Customer Code).
- One-click customer account suspension/activation.
- Automatic license generation during customer onboarding.
- Customer detail modal showing active bound devices and license status.

### 3. Software License Management
- **Key Generation**: Cryptographically formatted license keys (`POS-XXXX-XXXX-XXXX`).
- **Flexible Validity Periods**: 30 Days (Monthly), 3 Months (Quarterly), 6 Months (Half-Yearly), 1 Year (Annual), or Permanent Lifetime.
- **Custom Hardware Limits**: Set max allowed devices (e.g. 1, 2, 5, 10, unlimited).
- **Interactive QR Code Generator**: Generates high-resolution QR codes (`qr_flutter`) embedded with license metadata for one-tap mobile/tablet camera activation in the POS app.
- **Lifecycle Actions**: Extend validity (+30d, +3m, +6m, +1y), modify device quota, renew expired licenses, suspend, or revoke.

### 4. Device Restriction & Fleet Management
Strict backend enforcement of hardware limits:
1. **Device Slot Validation**: When a POS terminal authenticates with a license key, the system checks if the device is already registered.
2. **Existing Device**: Allowed to connect immediately; updates `lastActiveAt`.
3. **New Device with Free Slot**: Automatically registers hardware (Device ID, Device Name, Device Type, OS, App Version) and consumes 1 slot.
4. **Device Limit Exceeded**: Immediately blocks connection and displays:
   > *"Device Limit Reached! Your license allows only 2 connected devices. Please remove an existing device or contact the administrator."*
5. **Remote Deactivation**: Administrators can remotely deactivate or block any device directly from the web panel, instantly freeing up a license slot for new hardware.

### 5. Interactive Client Device Simulator
Built directly into the Admin Panel (`/simulator`):
- Lets administrators test and simulate multi-device login scenarios in real time.
- Pre-configured with **ABC Supermarket** (2-Device License):
  - Click **Simulate Device 1** &rarr; **SUCCESS** (1/2 slots used).
  - Click **Simulate Device 2** &rarr; **SUCCESS** (2/2 slots used).
  - Click **Simulate Device 3** &rarr; **DENIED** with the exact error banner:
    *"Device Limit Reached! Your license allows only 2 connected devices. Please remove an existing device or contact the administrator."*
  - Remotely deactivate Device 1 from the panel, re-run Device 3 &rarr; **SUCCESS** (slot immediately freed).

### 6. Audit Logs & Connection History
- **Admin Activity Logs**: Full timestamped record of administrative actions (license generation, validity extensions, device limit adjustments, suspensions).
- **Device Connection History**: Real-time audit log of all connection attempts (terminal name, IP, outcome `ALLOWED` or `DENIED`, failure reason).

---

## 🚀 Running the Admin Panel

### Prerequisites
- Flutter SDK (v3.24+ or v3.41+)
- Google Chrome or any modern web browser

### Development Mode
```bash
cd admin_panel_web
flutter pub get
flutter run -d chrome
```

### Production Build
```bash
cd admin_panel_web
flutter build web --release
```
The compiled, production-ready static assets are generated in `admin_panel_web/build/web`. Deploy directly to Firebase Hosting, Cloudflare Pages, Vercel, AWS S3, or Nginx.

---

## 🔑 Default Administrator Credentials
- **Username / Email**: `admin@shopeeinv.com`
- **Password**: `admin123`
*(Pre-filled on the Admin Login screen for easy 1-click evaluation)*

---

## 📂 Project Architecture

```
admin_panel_web/
├── lib/
│   ├── core/
│   │   ├── models/
│   │   │   ├── activity_log_model.dart       # Admin audit trail
│   │   │   ├── connection_history_model.dart # Terminal connection events
│   │   │   ├── customer_model.dart           # Shop & client profiles
│   │   │   ├── device_model.dart             # Bound hardware device records
│   │   │   └── license_model.dart            # License metadata & expiry logic
│   │   ├── theme/
│   │   │   └── admin_theme.dart              # Modern dark SaaS theme
│   │   └── utils/
│   │       └── key_generator.dart            # POS-XXXX-XXXX-XXXX key engine
│   ├── screens/
│   │   ├── customers/
│   │   │   ├── customer_details_dialog.dart  # Modal profile & bound devices
│   │   │   └── customer_list_screen.dart     # Customer management & creation
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart         # KPI cards & analytics charts
│   │   ├── devices/
│   │   │   ├── device_history_screen.dart    # Connection attempts & blocks
│   │   │   └── device_list_screen.dart       # Fleet overview & remote deactivate
│   │   ├── expired/
│   │   │   └── expired_licenses_screen.dart  # 1-click renewal workbench
│   │   ├── licenses/
│   │   │   ├── generate_license_screen.dart  # Issue license form
│   │   │   ├── license_details_screen.dart   # QR code & metadata
│   │   │   └── license_list_screen.dart      # License keys list & actions
│   │   ├── login/
│   │   │   └── admin_login_screen.dart       # Secure admin auth screen
│   │   ├── logs/
│   │   │   └── activity_logs_screen.dart     # Timestamped admin action timeline
│   │   ├── settings/
│   │   │   └── settings_screen.dart          # System policies & JSON backup
│   │   ├── simulator/
│   │   │   └── device_simulator_screen.dart  # Real-time multi-device login tester
│   │   └── suspended/
│   │       └── suspended_accounts_screen.dart# Blocked customers & quick unblock
│   ├── services/
│   │   └── license_service.dart              # State management & atomic device enforcement
│   ├── widgets/
│   │   ├── confirmation_dialog.dart          # Reusable action confirmation dialog
│   │   ├── sidebar.dart                      # Responsive desktop/drawer navigation
│   │   ├── stat_card.dart                    # Modern metric card
│   │   └── top_navbar.dart                   # Header bar with status badges
│   └── main.dart                             # App entry point & shell routing
└── web/
    └── index.html                            # Web host page with metadata & styling
```
