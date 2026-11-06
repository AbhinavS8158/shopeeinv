import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/license_model.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';
import 'license_details_screen.dart';

class LicenseListScreen extends StatefulWidget {
  final VoidCallback onOpenGenerate;

  const LicenseListScreen({super.key, required this.onOpenGenerate});

  @override
  State<LicenseListScreen> createState() => _LicenseListScreenState();
}

class _LicenseListScreenState extends State<LicenseListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _tierFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();

    final filtered = service.licenses.where((l) {
      final matchesQuery = _searchQuery.isEmpty ||
          l.licenseKey.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.customerName.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _statusFilter == 'ALL' || l.effectiveStatus == _statusFilter;
      final matchesTier = _tierFilter == 'ALL' || l.licenseType == _tierFilter;

      return matchesQuery && matchesStatus && matchesTier;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Software License Keys',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textWhite, letterSpacing: -0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Issue, extend validity, adjust hardware device limits, and monitor activations.',
                    style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: widget.onOpenGenerate,
                icon: const Icon(Icons.add_circle_outline, size: 16),
                label: const Text('Generate License', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AdminTheme.panelBg.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(fontSize: 13, color: AdminTheme.textWhite),
                    decoration: InputDecoration(
                      hintText: 'Search license key or customer name...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: AdminTheme.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      fillColor: AdminTheme.scaffoldBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AdminTheme.scaffoldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      dropdownColor: AdminTheme.panelBg,
                      style: const TextStyle(fontSize: 13, color: AdminTheme.textWhite),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(value: 'Expired', child: Text('Expired')),
                        DropdownMenuItem(value: 'Suspended', child: Text('Suspended')),
                      ],
                      onChanged: (v) => setState(() => _statusFilter = v ?? 'ALL'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AdminTheme.scaffoldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminTheme.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _tierFilter,
                      dropdownColor: AdminTheme.panelBg,
                      style: const TextStyle(fontSize: 13, color: AdminTheme.textWhite),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Tiers')),
                        DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                        DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                        DropdownMenuItem(value: 'Enterprise', child: Text('Enterprise')),
                        DropdownMenuItem(value: 'Trial', child: Text('Trial')),
                      ],
                      onChanged: (v) => setState(() => _tierFilter = v ?? 'ALL'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Licenses Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.panelBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
              ),
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No licenses found.', style: TextStyle(color: AdminTheme.textMuted)),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B), height: 1),
                        itemBuilder: (context, index) {
                          final lic = filtered[index];
                          final activeDevCount = service.devices.where((d) => d.licenseId == lic.id && d.status == 'Active').length;
                          final isExpired = lic.effectiveStatus == 'Expired';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                // Key Icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isExpired
                                        ? AdminTheme.danger.withValues(alpha: 0.15)
                                        : AdminTheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.vpn_key,
                                    size: 20,
                                    color: isExpired ? AdminTheme.danger : AdminTheme.primaryLight,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // License Key & Copy Button
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            lic.licenseKey,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                              color: AdminTheme.textWhite,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: lic.licenseKey));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('License Key copied to clipboard!'), duration: Duration(seconds: 2)),
                                              );
                                            },
                                            child: const Icon(Icons.copy, size: 14, color: AdminTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Customer: ${lic.customerName}',
                                        style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),

                                // Tier Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    lic.licenseType,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.primaryLight),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Device Limit
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$activeDevCount / ${lic.maxDevices} devices',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
                                      ),
                                      InkWell(
                                        onTap: () => _showChangeLimitDialog(context, lic),
                                        child: const Text('Change Limit', style: TextStyle(fontSize: 10, color: AdminTheme.primaryLight, fontWeight: FontWeight.w600)),
                                      ),
                                    ],
                                  ),
                                ),

                                // Expiration
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        lic.expiresAt != null ? DateFormat('dd MMM yyyy').format(lic.expiresAt!) : 'Permanent Lifetime',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isExpired ? AdminTheme.danger : AdminTheme.textWhite,
                                        ),
                                      ),
                                      Text(
                                        'Type: ${lic.validityType}',
                                        style: const TextStyle(fontSize: 10, color: AdminTheme.textSubtle),
                                      ),
                                    ],
                                  ),
                                ),

                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: lic.effectiveStatus == 'Active'
                                        ? AdminTheme.success.withValues(alpha: 0.15)
                                        : AdminTheme.danger.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    lic.effectiveStatus,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: lic.effectiveStatus == 'Active' ? AdminTheme.success : AdminTheme.danger,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Actions
                                IconButton(
                                  icon: const Icon(Icons.qr_code, size: 18, color: AdminTheme.primaryLight),
                                  tooltip: 'View Key & QR Code',
                                  onPressed: () => LicenseDetailsScreen.show(context, lic),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.calendar_month, size: 18, color: AdminTheme.success),
                                  tooltip: 'Extend Validity',
                                  onPressed: () => _showExtendDialog(context, lic),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 18, color: AdminTheme.textMuted),
                                  color: AdminTheme.panelBg,
                                  onSelected: (val) {
                                    if (val == 'suspend') {
                                      service.updateLicenseStatus(lic.id, 'Suspended');
                                    } else if (val == 'activate') {
                                      service.updateLicenseStatus(lic.id, 'Active');
                                    } else if (val == 'revoke') {
                                      service.updateLicenseStatus(lic.id, 'Revoked');
                                    } else if (val == 'renew') {
                                      service.renewLicense(lic.id);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    if (lic.status != 'Active')
                                      const PopupMenuItem(value: 'activate', child: Text('Set as Active', style: TextStyle(color: AdminTheme.success))),
                                    if (lic.status == 'Active')
                                      const PopupMenuItem(value: 'suspend', child: Text('Suspend License', style: TextStyle(color: AdminTheme.warning))),
                                    const PopupMenuItem(value: 'revoke', child: Text('Revoke License', style: TextStyle(color: AdminTheme.danger))),
                                    if (isExpired)
                                      const PopupMenuItem(value: 'renew', child: Text('Renew (1 Year)', style: TextStyle(color: AdminTheme.primaryLight))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeLimitDialog(BuildContext context, LicenseModel lic) {
    int current = lic.maxDevices;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: AdminTheme.panelBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AdminTheme.borderColor)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Adjust Maximum Devices', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                const SizedBox(height: 8),
                Text('License: ${lic.licenseKey} • Current Limit: ${lic.maxDevices}', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  children: [1, 2, 3, 5, 10, 20].map((d) {
                    return ChoiceChip(
                      label: Text('$d Devices'),
                      selected: current == d,
                      onSelected: (_) => setModalState(() => current = d),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        context.read<LicenseService>().updateDeviceLimit(lic.id, current);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Save Limit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExtendDialog(BuildContext context, LicenseModel lic) {
    String duration = '1_year';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: AdminTheme.panelBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AdminTheme.borderColor)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Extend License Validity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                const SizedBox(height: 8),
                Text('Add duration to ${lic.licenseKey}', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: duration,
                  dropdownColor: AdminTheme.panelBg,
                  decoration: const InputDecoration(labelText: 'Add Duration'),
                  items: const [
                    DropdownMenuItem(value: '30_days', child: Text('+30 Days (1 Month)')),
                    DropdownMenuItem(value: '3_months', child: Text('+3 Months (Quarterly)')),
                    DropdownMenuItem(value: '6_months', child: Text('+6 Months (Half-Yearly)')),
                    DropdownMenuItem(value: '1_year', child: Text('+1 Year (Annual)')),
                    DropdownMenuItem(value: 'lifetime', child: Text('Permanent Lifetime')),
                  ],
                  onChanged: (v) => setModalState(() => duration = v ?? '1_year'),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        context.read<LicenseService>().extendLicenseValidity(lic.id, duration);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Extend Now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
