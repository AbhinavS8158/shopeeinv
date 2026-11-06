import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/auth_license_info.dart';
import '../../core/models/license_request_model.dart';
import '../../core/models/shop_profile.dart';
import '../../core/services/auth_api_service.dart';
import '../../core/services/license_request_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/dashboard_screen.dart';
import 'device_limit_dialog.dart';
import 'license_request_screen.dart';
import 'shop_setup_screen.dart';

class LicenseStatusScreen extends StatefulWidget {
  final ShopProfile shop;
  final bool isExpired;

  const LicenseStatusScreen({
    super.key,
    required this.shop,
    this.isExpired = false,
  });

  @override
  State<LicenseStatusScreen> createState() => _LicenseStatusScreenState();
}

class _LicenseStatusScreenState extends State<LicenseStatusScreen> {
  bool _isChecking = false;
  LicenseRequestModel? _latestRequest;
  AuthLicenseInfo? _activeLicense;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _isChecking = true);

    // 1. Check if active approved license exists
    final lic = await LicenseRequestService.getActiveLicense(user.id);
    // 2. Check latest request status
    final req = await LicenseRequestService.getLatestRequest(user.id);

    if (mounted) {
      setState(() {
        _activeLicense = lic;
        _latestRequest = req;
        _isChecking = false;
      });

      if (lic != null && lic.isValid) {
        auth.setLicense(lic);
      }
    }
  }

  Future<void> _proceedToDashboard() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    final license = _activeLicense ?? auth.currentLicense;

    if (user == null || license == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('License details not loaded yet. Please refresh.')),
      );
      return;
    }

    setState(() => _isChecking = true);

    // Validate hardware terminal limit
    final devResult = await AuthApiService.registerDevice(
      customerId: user.id,
      customerName: user.name,
      license: license,
    );

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (devResult.success) {
      auth.setLicense(license);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      DeviceLimitDialog.show(context, devResult.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    // Determine current effective state:
    // 1. Expired
    // 2. Approved (has valid active license)
    // 3. Rejected (latest request rejected)
    // 4. Pending (latest request pending)
    // 5. None / Not Requested yet

    final bool isExpiredState = widget.isExpired || (_activeLicense != null && _activeLicense!.isExpired);
    final bool isApprovedState = !isExpiredState && (_activeLicense != null && _activeLicense!.isValid);
    final bool isRejectedState = !isApprovedState && (_latestRequest != null && _latestRequest!.isRejected);
    final bool isPendingState = !isApprovedState && !isRejectedState;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('License Approval Status'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _isChecking ? null : _fetchStatus,
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<LicenseRequestModel?>(
          stream: user != null ? LicenseRequestService.streamLatestRequest(user.id) : const Stream.empty(),
          builder: (context, snapshot) {
            final request = snapshot.data ?? _latestRequest;

            // Real-time update check
            if (request != null && request.isApproved && _activeLicense == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _fetchStatus());
            }

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isExpiredState) ...[
                        _buildExpiredCard(),
                      ] else if (isApprovedState) ...[
                        _buildApprovedCard(),
                      ] else if (isRejectedState) ...[
                        _buildRejectedCard(request),
                      ] else ...[
                        _buildPendingCard(request),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 1. PENDING STATE CARD
  Widget _buildPendingCard(LicenseRequestModel? request) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hourglass_top_rounded, size: 54, color: Colors.amber.shade800),
            ),
            const SizedBox(height: 20),
            const Text(
              'Awaiting Admin Approval',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your license request has been submitted and is currently being reviewed by the administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  _buildSummaryItem('Shop Name', widget.shop.shopName),
                  const Divider(height: 16),
                  _buildSummaryItem('Status', 'PENDING REVIEW', valueColor: Colors.amber.shade900),
                  if (request != null) ...[
                    const Divider(height: 16),
                    _buildSummaryItem('Request ID', request.id),
                    const Divider(height: 16),
                    _buildSummaryItem('Submitted On', DateFormat('dd/MM/yyyy hh:mm a').format(request.requestedAt)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _isChecking ? null : _fetchStatus,
              icon: _isChecking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: const Text('Check Status'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. APPROVED / ACTIVE STATE CARD
  Widget _buildApprovedCard() {
    final license = _activeLicense!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified_rounded, size: 54, color: Colors.green.shade700),
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'License Approved!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Your application license has been approved. You can now access ShopeeInv.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 24),

            // License Details Box
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.shade50.withAlpha(80),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('License Key', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppTheme.primary),
                        tooltip: 'Copy License Key',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: license.licenseKey));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('License Key copied to clipboard!')),
                          );
                        },
                      ),
                    ],
                  ),
                  Text(
                    license.licenseKey,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                  const Divider(height: 24),
                  _buildSummaryItem('License Type', '${license.licenseType} Plan'),
                  const Divider(height: 16),
                  _buildSummaryItem('Allowed Devices', '${license.maxDevices} Concurrent Terminals'),
                  if (license.expiresAt != null) ...[
                    const Divider(height: 16),
                    _buildSummaryItem(
                      'Valid Until',
                      DateFormat('dd/MM/yyyy').format(license.expiresAt!),
                      valueColor: Colors.green.shade800,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Proceed to Dashboard Button
            ElevatedButton.icon(
              onPressed: _isChecking ? null : _proceedToDashboard,
              icon: _isChecking
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continue to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. REJECTED STATE CARD
  Widget _buildRejectedCard(LicenseRequestModel? request) {
    final reason = request?.rejectionReason ?? 'Information provided was insufficient or incomplete.';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cancel_outlined, size: 54, color: Colors.red.shade700),
            ),
            const SizedBox(height: 18),
            const Text(
              'License Request Rejected',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your license request could not be approved by the administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // Admin Reason Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.report_problem_outlined, size: 18, color: Colors.red.shade800),
                      const SizedBox(width: 8),
                      Text(
                        'Reason from Administrator:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red.shade900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    style: TextStyle(fontSize: 13, color: Colors.red.shade800, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action: Edit & Resubmit
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LicenseRequestScreen(shop: widget.shop),
                  ),
                );
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Update Details & Resubmit Request'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ShopSetupScreen(existingShop: widget.shop)),
                );
              },
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit Shop Profile Details'),
            ),
          ],
        ),
      ),
    );
  }

  // 4. EXPIRED STATE CARD
  Widget _buildExpiredCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.timer_off_outlined, size: 54, color: Colors.orange.shade800),
            ),
            const SizedBox(height: 18),
            const Text(
              'License Expired',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your application license has expired. Please contact the administrator for renewal.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LicenseRequestScreen(shop: widget.shop)),
                );
              },
              icon: const Icon(Icons.autorenew),
              label: const Text('Request License Renewal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
