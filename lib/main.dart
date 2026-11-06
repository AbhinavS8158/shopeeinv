import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/database/app_database.dart';
import 'core/database/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/billing_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/cash_register_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/product_provider.dart';
import 'providers/shop_provider.dart';
import 'screens/auth/shop_setup_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'firebase_options.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Try initializing Firebase safely (offline fallback if options not yet configured)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase not configured or offline mode: $e');
  }

  // Initialize SQLite Database
  await AppDatabase.instance.database;

  // Initialize Offline/Online Sync Service
  await SyncService.instance.init();

  runApp(const ShopeeInvApp());
}

class ShopeeInvApp extends StatelessWidget {
  const ShopeeInvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ShopProvider()..loadShops()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => BillingProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => CashRegisterProvider()),
      ],
      child: MaterialApp(
        title: 'ShopeeInv - Multi-Shop Billing & Inventory',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    await shopProvider.loadShops();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, shopProvider, _) {
        if (shopProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading ShopeeInv Billing System...'),
                ],
              ),
            ),
          );
        }

        // If no shop is registered yet, show Shop Setup / Business Profile onboarding screen!
        if (!shopProvider.hasShop) {
          return const ShopSetupScreen();
        }

        // Otherwise open the Dashboard!
        return const DashboardScreen();
      },
    );
  }
}
