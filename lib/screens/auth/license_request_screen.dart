import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/shop_profile.dart';
import '../../core/services/license_request_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'license_status_screen.dart';

class LicenseRequestScreen extends StatefulWidget {
  final ShopProfile shop;
  final String businessType;

  const LicenseRequestScreen({
    super.key,
    required this.shop,
    this.businessType = 'Retail Store',
  });

  @override
  State<LicenseRequestScreen> createState() => _LicenseRequestScreenState();
}

class _LicenseRequestScreenState extends State<LicenseRequestScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;

    if (user == null) {
      setState(() => _errorMessage = 'User session not found. Please log in again.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final res = await LicenseRequestService.submitLicenseRequest(
      user: user,
      shop: widget.shop,
      businessType: widget.businessType,
      notes: _notesController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (res.success && res.data != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.success,
          duration: Duration(seconds: 4),
          content: Text(
            'Your license request has been submitted successfully. Please wait for admin approval. You will be notified once your license is activated.',
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LicenseStatusScreen(shop: widget.shop),
        ),
      );
    } else {
      setState(() {
        _errorMessage = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Application License Request'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Step Indicator Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(40),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Step 2: License Request',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Submit your business registration to the ShopeeInv admin for terminal license issuance.',
                                style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Banner
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.danger.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(fontSize: 13, color: AppTheme.danger),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Details Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Request Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const Divider(height: 24),

                          // User Details
                          _buildDetailRow(Icons.person, 'Owner / User Name', user?.name ?? widget.shop.ownerName),
                          const SizedBox(height: 12),

                          // Shop Name
                          _buildDetailRow(Icons.storefront, 'Shop Name', widget.shop.shopName),
                          const SizedBox(height: 12),

                          // Business Type
                          _buildDetailRow(Icons.category_outlined, 'Business Type', widget.businessType),
                          const SizedBox(height: 12),

                          // Registered Email
                          _buildDetailRow(Icons.email_outlined, 'Registered Email', user?.email ?? widget.shop.email),
                          const SizedBox(height: 12),

                          // Phone Number
                          _buildDetailRow(Icons.phone_outlined, 'Phone Number', widget.shop.phone),
                          const SizedBox(height: 12),

                          // Shop ID
                          _buildDetailRow(Icons.tag, 'Shop ID', widget.shop.id),
                          const SizedBox(height: 12),

                          // License Status
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: AppTheme.textSecondary),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('License Status', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Awaiting Request',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),

                          // Optional Notes
                          TextField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              labelText: 'Additional Notes / Requirements (Optional)',
                              hintText: 'e.g. Need 2 mobile billing terminals for grocery counter',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Request Button
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: const Text(
                      'Request Application License',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'N/A',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
