import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../dashboard/dashboard_screen.dart';
import 'shop_setup_screen.dart';
import 'sign_up_screen.dart';
import 'forgot_password_dialog.dart';
import 'device_limit_dialog.dart';
import '../../core/services/license_request_service.dart';
import '../../core/services/auth_api_service.dart';
import 'license_request_screen.dart';
import 'license_status_screen.dart';

class SignInScreen extends StatefulWidget {
  final String? prefillEmail;

  const SignInScreen({super.key, this.prefillEmail});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null && widget.prefillEmail!.isNotEmpty) {
      _emailController.text = widget.prefillEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    if (success) {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      await shopProvider.loadShops();

      if (!mounted) return;

      if (!shopProvider.hasShop) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ShopSetupScreen()),
          (route) => false,
        );
        return;
      }

      final shop = shopProvider.currentShop!;
      final user = auth.currentUser!;

      // Check License & License Request workflow
      final activeLic = await LicenseRequestService.getActiveLicense(user.id);
      if (activeLic != null && activeLic.isValid) {
        final devCheck = await AuthApiService.registerDevice(
          customerId: user.id,
          customerName: user.name,
          license: activeLic,
        );
        if (!mounted) return;
        if (devCheck.success) {
          auth.setLicense(activeLic);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          );
        } else {
          DeviceLimitDialog.show(context, devCheck.message);
        }
        return;
      }

      // Check request status
      final req = await LicenseRequestService.getLatestRequest(user.id);
      if (!mounted) return;

      if (req == null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LicenseRequestScreen(shop: shop)),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LicenseStatusScreen(shop: shop)),
          (route) => false,
        );
      }
    } else {
      // Check if error is related to device limit
      final err = auth.errorMessage ?? '';
      if (err.contains('Device Limit') || err.contains('device slots')) {
        DeviceLimitDialog.show(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 90,
                      height: 90,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(30),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/icon/app_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.storefront,
                            size: 48,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Brand Title
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
                            color: Color(0xFFF97316),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Multi-Shop Billing & Inventory Management',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Login Card Form
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Enter your email address and password to continue',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 20),

                            // Error Alert Banner
                            if (auth.errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.danger.withAlpha(60)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        auth.errorMessage!,
                                        style: const TextStyle(fontSize: 13, color: AppTheme.danger),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // 1. Email Address (Only email and password allowed)
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email Address *',
                                hintText: 'name@business.com',
                                prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryLight),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Email Address is required';
                                }
                                final clean = value.trim().toLowerCase();
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(clean)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // 2. Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password *',
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.primaryLight),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: AppTheme.textSecondary,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Remember Me & Forgot Password Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        activeColor: AppTheme.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (val) {
                                          setState(() => _rememberMe = val ?? true);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Remember Me',
                                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    ForgotPasswordDialog.show(
                                      context,
                                      initialEmail: _emailController.text.trim(),
                                    );
                                  },
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.primaryLight,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Sign In Button
                            ElevatedButton(
                              onPressed: auth.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Sign In',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Navigation to Sign Up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SignUpScreen()),
                          );
                        },
                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
