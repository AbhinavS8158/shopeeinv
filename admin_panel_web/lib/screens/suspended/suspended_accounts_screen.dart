import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';
import '../../widgets/confirmation_dialog.dart';

class SuspendedAccountsScreen extends StatelessWidget {
  const SuspendedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final blocked = service.customers.where((c) => c.status == 'Blocked').toList();

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
                  color: AdminTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_off_outlined, color: AdminTheme.warning, size: 24),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suspended & Blocked Accounts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AdminTheme.textWhite)),
                  Text('Customer accounts blocked by administrator. All device connections from these accounts are rejected.', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
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
              child: blocked.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 48, color: AdminTheme.success),
                          SizedBox(height: 12),
                          Text('No blocked accounts!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                          SizedBox(height: 4),
                          Text('All customer accounts are in good standing.', style: TextStyle(color: AdminTheme.textMuted, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: blocked.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final c = blocked[idx];

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AdminTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminTheme.warning.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AdminTheme.warning.withValues(alpha: 0.2),
                                child: const Icon(Icons.block, color: AdminTheme.warning, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.shopName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                                    const SizedBox(height: 2),
                                    Text('${c.name} • ${c.email}', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  c.notes.isNotEmpty ? c.notes : 'No suspension notes recorded.',
                                  style: const TextStyle(fontSize: 12, color: AdminTheme.warning),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final confirm = await ConfirmationDialog.show(
                                    context: context,
                                    title: 'Unblock Account?',
                                    message: 'Restore POS device access for "${c.shopName}"?',
                                    confirmText: 'Unblock Account',
                                    confirmColor: AdminTheme.success,
                                  );
                                  if (confirm) {
                                    service.toggleCustomerStatus(c.id);
                                  }
                                },
                                icon: const Icon(Icons.lock_open, size: 16),
                                label: const Text('Unblock Account'),
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
}
