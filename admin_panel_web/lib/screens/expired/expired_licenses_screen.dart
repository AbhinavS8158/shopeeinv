import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/license_model.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';

class ExpiredLicensesScreen extends StatelessWidget {
  const ExpiredLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final expired = service.licenses.where((l) => l.effectiveStatus == 'Expired').toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminTheme.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.timer_off_outlined, color: AdminTheme.danger, size: 24),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expired Licenses', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AdminTheme.textWhite)),
                  Text('Customers with expired subscriptions whose POS devices are blocked from sync.', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.panelBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
              ),
              child: expired.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: AdminTheme.success),
                          SizedBox(height: 12),
                          Text('No expired licenses!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                          SizedBox(height: 4),
                          Text('All customer licenses are currently active and valid.', style: TextStyle(color: AdminTheme.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: expired.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final lic = expired[idx];
                        final daysAgo = lic.expiresAt != null
                            ? DateTime.now().difference(lic.expiresAt!).inDays
                            : 0;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AdminTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminTheme.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AdminTheme.danger.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.vpn_key, color: AdminTheme.danger, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lic.licenseKey, style: const TextStyle(fontSize: 15, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                                    const SizedBox(height: 2),
                                    Text('Customer: ${lic.customerName}', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Expired: ${lic.expiresAt != null ? DateFormat("dd MMM yyyy").format(lic.expiresAt!) : ""}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.danger)),
                                    Text('$daysAgo day${daysAgo != 1 ? "s" : ""} ago', style: const TextStyle(fontSize: 10, color: AdminTheme.textSubtle)),
                                  ],
                                ),
                              ),
                              Text('Quota: ${lic.maxDevices} devices', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                              const SizedBox(width: 20),
                              ElevatedButton.icon(
                                onPressed: () => _showRenewDialog(context, lic),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Renew License'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminTheme.success,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenewDialog(BuildContext context, LicenseModel lic) {
    String validity = '1_year';

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
                const Text('Renew Expired License', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                const SizedBox(height: 8),
                Text('Customer: ${lic.customerName} • ${lic.licenseKey}', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: validity,
                  dropdownColor: AdminTheme.panelBg,
                  decoration: const InputDecoration(labelText: 'Renewal Duration'),
                  items: const [
                    DropdownMenuItem(value: '1_year', child: Text('1 Year from today')),
                    DropdownMenuItem(value: '30_days', child: Text('30 Days')),
                    DropdownMenuItem(value: '3_months', child: Text('3 Months')),
                    DropdownMenuItem(value: '6_months', child: Text('6 Months')),
                    DropdownMenuItem(value: 'lifetime', child: Text('Permanent Lifetime')),
                  ],
                  onChanged: (v) => setModalState(() => validity = v ?? '1_year'),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.success),
                      onPressed: () {
                        context.read<LicenseService>().renewLicense(lic.id, validityType: validity);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('License renewed and set to Active!'), duration: Duration(seconds: 2)),
                        );
                      },
                      child: const Text('Renew Now'),
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
