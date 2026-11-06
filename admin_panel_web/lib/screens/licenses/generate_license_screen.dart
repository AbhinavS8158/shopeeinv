import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';

class GenerateLicenseScreen extends StatefulWidget {
  final VoidCallback onDone;

  const GenerateLicenseScreen({super.key, required this.onDone});

  @override
  State<GenerateLicenseScreen> createState() => _GenerateLicenseScreenState();
}

class _GenerateLicenseScreenState extends State<GenerateLicenseScreen> {
  String? _selectedCustomerId;
  String _licenseTier = 'Standard';
  String _validityType = '1_year';
  int _deviceLimit = 2;
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final customers = service.customers;

    if (_selectedCustomerId == null && customers.isNotEmpty) {
      _selectedCustomerId = customers.first.id;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button & Title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AdminTheme.textMuted),
                    onPressed: widget.onDone,
                  ),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generate & Issue License Key',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AdminTheme.textWhite),
                      ),
                      Text(
                        'Create a unique license key, bind to customer, and configure device quota.',
                        style: TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AdminTheme.panelBg.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Target Customer
                    const Text('TARGET CUSTOMER / SHOP *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminTheme.textMuted)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCustomerId,
                      dropdownColor: AdminTheme.panelBg,
                      decoration: const InputDecoration(hintText: 'Select registered customer'),
                      items: customers.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text('${c.shopName} (${c.name}) [${c.customerCode}]'),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedCustomerId = v),
                    ),
                    const SizedBox(height: 20),

                    // License Tier
                    const Text('LICENSE TIER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminTheme.textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: ['Standard', 'Premium', 'Enterprise', 'Trial'].map((tier) {
                        final isSel = _licenseTier == tier;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => setState(() => _licenseTier = tier),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSel ? AdminTheme.primary : AdminTheme.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSel ? AdminTheme.primary : AdminTheme.borderColor),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  tier,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel ? Colors.white : AdminTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Validity Period
                    const Text('VALIDITY DURATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminTheme.textMuted)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _validityType,
                      dropdownColor: AdminTheme.panelBg,
                      items: const [
                        DropdownMenuItem(value: '1_year', child: Text('1 Year (Annual Subscription)')),
                        DropdownMenuItem(value: '30_days', child: Text('30 Days (Monthly)')),
                        DropdownMenuItem(value: '3_months', child: Text('3 Months (Quarterly)')),
                        DropdownMenuItem(value: '6_months', child: Text('6 Months (Half-Yearly)')),
                        DropdownMenuItem(value: 'lifetime', child: Text('Permanent Lifetime Access')),
                      ],
                      onChanged: (v) => setState(() => _validityType = v ?? '1_year'),
                    ),
                    const SizedBox(height: 20),

                    // Device Limit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('MAXIMUM DEVICE LIMIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminTheme.textMuted)),
                        Text('$_deviceLimit Devices Allowed', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.primaryLight)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [1, 2, 3, 5, 10].map((d) {
                        final isSel = _deviceLimit == d;
                        return ChoiceChip(
                          label: Text(d == 2 ? '2 (Standard)' : '$d Device${d > 1 ? "s" : ""}'),
                          selected: isSel,
                          onSelected: (_) => setState(() => _deviceLimit = d),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Notes
                    const Text('ADMIN NOTES / INVOICE INFO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminTheme.textMuted)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Paid via UPI invoice #INV-902, authorized for 2 billing counters',
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.vpn_key),
                        label: const Text('Generate & Assign License Key', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () {
                          if (_selectedCustomerId == null) return;
                          service.generateLicense(
                            customerId: _selectedCustomerId!,
                            licenseType: _licenseTier,
                            validityType: _validityType,
                            maxDevices: _deviceLimit,
                            notes: _notesCtrl.text.trim(),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('License issued successfully!'), duration: Duration(seconds: 2)),
                          );
                          widget.onDone();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
