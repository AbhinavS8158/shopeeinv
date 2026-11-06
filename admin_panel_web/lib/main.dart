import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/admin_theme.dart';
import 'services/license_service.dart';
import 'widgets/sidebar.dart';
import 'widgets/top_navbar.dart';
import 'screens/login/admin_login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/customers/customer_list_screen.dart';
import 'screens/licenses/license_list_screen.dart';
import 'screens/licenses/generate_license_screen.dart';
import 'screens/devices/device_list_screen.dart';
import 'screens/devices/device_history_screen.dart';
import 'screens/expired/expired_licenses_screen.dart';
import 'screens/suspended/suspended_accounts_screen.dart';
import 'screens/logs/activity_logs_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/simulator/device_simulator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }
  runApp(const ShopeeInvAdminApp());
}

class ShopeeInvAdminApp extends StatelessWidget {
  const ShopeeInvAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LicenseService(),
      child: MaterialApp(
        title: 'ShopeeInv – Admin Panel & License Manager',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.darkTheme,
        home: const AdminAppShell(),
      ),
    );
  }
}

class AdminAppShell extends StatefulWidget {
  const AdminAppShell({super.key});

  @override
  State<AdminAppShell> createState() => _AdminAppShellState();
}

class _AdminAppShellState extends State<AdminAppShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();

    // If not authenticated, display Admin Login screen
    if (!service.isAuthenticated) {
      return const AdminLoginScreen();
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    Widget bodyWidget;
    switch (_currentIndex) {
      case 0:
        bodyWidget = DashboardScreen(onNavigate: _navigateTo);
        break;
      case 1:
        bodyWidget = const CustomerListScreen();
        break;
      case 2:
        bodyWidget = LicenseListScreen(onOpenGenerate: () => _navigateTo(10));
        break;
      case 3:
        bodyWidget = DeviceListScreen(onOpenSimulator: () => _navigateTo(8));
        break;
      case 4:
        bodyWidget = const DeviceHistoryScreen();
        break;
      case 5:
        bodyWidget = const ExpiredLicensesScreen();
        break;
      case 6:
        bodyWidget = const SuspendedAccountsScreen();
        break;
      case 7:
        bodyWidget = const ActivityLogsScreen();
        break;
      case 8:
        bodyWidget = const DeviceSimulatorScreen();
        break;
      case 9:
        bodyWidget = const SettingsScreen();
        break;
      case 10:
        bodyWidget = GenerateLicenseScreen(onDone: () => _navigateTo(2));
        break;
      default:
        bodyWidget = DashboardScreen(onNavigate: _navigateTo);
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: isDesktop
          ? null
          : Drawer(
              child: AdminSidebar(
                selectedIndex: _currentIndex,
                onSelectIndex: _navigateTo,
              ),
            ),
      body: Row(
        children: [
          // Desktop Permanent Sidebar
          if (isDesktop)
            AdminSidebar(
              selectedIndex: _currentIndex,
              onSelectIndex: _navigateTo,
            ),

          // Main View Content Area
          Expanded(
            child: Column(
              children: [
                TopNavbar(
                  onOpenMenu: () => _scaffoldKey.currentState?.openDrawer(),
                  onOpenSimulator: () => _navigateTo(8),
                  onIssueLicense: () => _navigateTo(10),
                ),
                Expanded(
                  child: Container(
                    color: AdminTheme.scaffoldBg,
                    child: bodyWidget,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
