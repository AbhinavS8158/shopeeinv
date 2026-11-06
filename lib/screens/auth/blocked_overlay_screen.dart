import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/block_enforcement_provider.dart';
import 'sign_in_screen.dart';

class BlockEnforcementWrapper extends StatelessWidget {
  final Widget child;

  const BlockEnforcementWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<BlockEnforcementProvider>(
      builder: (context, blockProv, _) {
        if (!blockProv.isBlocked) {
          return child;
        }

        return Stack(
          children: [
            // Freeze underlying content completely: absorb all touch/click/scroll events
            AbsorbPointer(
              absorbing: true,
              child: child,
            ),
            // Un-dismissible Full Screen Freeze Overlay
            const BlockedOverlayScreen(),
          ],
        );
      },
    );
  }
}

class BlockedOverlayScreen extends StatefulWidget {
  const BlockedOverlayScreen({super.key});

  @override
  State<BlockedOverlayScreen> createState() => _BlockedOverlayScreenState();
}

class _BlockedOverlayScreenState extends State<BlockedOverlayScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blockProv = context.watch<BlockEnforcementProvider>();
    final authProv = context.read<AuthProvider>();

    final shopName = blockProv.blockedShopName ?? authProv.currentUser?.shopName ?? 'ShopeeInv Merchant';
    final email = blockProv.blockedUserEmail ?? authProv.currentUser?.email ?? 'merchant@store.com';
    final licenseKey = blockProv.blockedLicenseKey ?? authProv.currentLicense?.licenseKey ?? 'N/A';
    final reason = blockProv.blockReason ?? 'Administrative License / Account Suspension';
    final blockedTime = blockProv.blockedAt ?? DateTime.now();

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF090D16),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Pulsing Alert Icon
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.danger.withAlpha(35),
                          border: Border.all(color: AppTheme.danger, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.danger.withAlpha(90),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.gpp_bad_rounded,
                          size: 56,
                          color: AppTheme.danger,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Top Primary Alert Banner (Exact user wording)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.danger.withAlpha(120), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Your account has been blocked . please contact Admin team',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Explanatory note
                    const Text(
                      'Terminal Access Frozen',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This application terminal has been suspended by the central system administrator. All billing counters, inventory mutations, and data actions are completely locked.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade400, height: 1.4),
                    ),
                    const SizedBox(height: 22),

                    // Account & Terminal Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Terminal Details',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withAlpha(40),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.danger.withAlpha(120)),
                                ),
                                child: const Text(
                                  'BLOCKED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.danger,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Color(0xFF1E293B), height: 18),
                          _buildDetailRow('Shop Name:', shopName),
                          const SizedBox(height: 6),
                          _buildDetailRow('User Email:', email),
                          if (licenseKey != 'N/A') ...[
                            const SizedBox(height: 6),
                            _buildDetailRow('License Key:', licenseKey, isMonospace: true),
                          ],
                          const SizedBox(height: 6),
                          _buildDetailRow('Suspension Reason:', reason, color: Colors.amber.shade300),
                          const SizedBox(height: 6),
                          _buildDetailRow(
                            'Enforced At:',
                            DateFormat('dd MMM yyyy, hh:mm a').format(blockedTime),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Admin Support Helpdesk Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryLight.withAlpha(60)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.headset_mic_outlined, size: 18, color: AppTheme.primaryLight),
                              SizedBox(width: 8),
                              Text(
                                'Admin Team & Helpdesk Contact',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Please contact your organization administrator or write to support@shopeeinv.com with your shop name to reactivate this license terminal.',
                            style: TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.logout, size: 16),
                            label: const Text('SIGN OUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            onPressed: () async {
                              await authProv.logout();
                              blockProv.stopMonitoring();
                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(builder: (_) => const SignInScreen()),
                                  (route) => false,
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: blockProv.isChecking
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 16),
                            label: Text(
                              blockProv.isChecking ? 'CHECKING...' : 'CHECK STATUS',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: blockProv.isChecking
                                ? null
                                : () async {
                                    final stillBlocked = await blockProv.checkFullStatus();
                                    if (context.mounted && stillBlocked) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Account is still blocked. Please contact the Admin team.'),
                                          backgroundColor: AppTheme.danger,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
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
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMonospace = false, Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: isMonospace ? 'monospace' : null,
              color: color ?? Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
