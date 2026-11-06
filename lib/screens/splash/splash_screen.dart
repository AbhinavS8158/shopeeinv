import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/shop_provider.dart';
import '../auth/shop_setup_screen.dart';
import '../../providers/auth_provider.dart';
import '../auth/sign_in_screen.dart';
import '../../core/services/license_request_service.dart';
import '../auth/license_request_screen.dart';
import '../auth/license_status_screen.dart';
import '../dashboard/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    _animController.forward();

    // Load initial data while showing splash
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    shopProvider.loadShops();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Exactly 3 seconds splash duration
    Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final isAuthenticated = authProvider.isAuthenticated;

      Widget targetScreen;
      if (!isAuthenticated) {
        targetScreen = const SignInScreen();
      } else if (!shopProvider.hasShop) {
        targetScreen = const ShopSetupScreen();
      } else {
        final shop = shopProvider.currentShop!;
        final user = authProvider.currentUser;

        if (user != null) {
          final activeLic = await LicenseRequestService.getActiveLicense(user.id);
          if (activeLic != null && activeLic.isValid) {
            targetScreen = const DashboardScreen();
          } else {
            final req = await LicenseRequestService.getLatestRequest(user.id);
            if (req == null) {
              targetScreen = LicenseRequestScreen(shop: shop);
            } else {
              targetScreen = LicenseStatusScreen(shop: shop);
            }
          }
        } else {
          targetScreen = const SignInScreen();
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => FadeTransition(
            opacity: animation,
            child: targetScreen,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient Subtle Aura
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryLight.withAlpha(20),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withAlpha(20),
              ),
            ),
          ),

          // Main Center Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Logo Container with shadow
                    Container(
                      width: 130,
                      height: 130,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(35),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icon/app_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.storefront,
                            size: 64,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // App Title
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Shopee',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'Inv',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF97316), // Accent Orange
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle / Tagline
                    const Text(
                      'Multi-Shop Billing & Inventory Management',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Loading & Version Tag
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryLight),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Offline-First GST Billing',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
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
