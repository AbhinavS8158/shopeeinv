import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';

class ActivityLogsScreen extends StatelessWidget {
  const ActivityLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final logs = service.activityLogs;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Activity & Audit Trail',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textWhite, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Immutable record of administrative operations: license issuance, limit adjustments, suspensions, and logins.',
            style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.panelBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
              ),
              child: logs.isEmpty
                  ? const Center(child: Text('No activity logs recorded.', style: TextStyle(color: AdminTheme.textMuted)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B)),
                      itemBuilder: (context, idx) {
                        final log = logs[idx];

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(DateFormat('dd MMM yyyy').format(log.createdAt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                                  Text(DateFormat('HH:mm:ss').format(log.createdAt), style: const TextStyle(fontSize: 10, color: AdminTheme.textSubtle)),
                                ],
                              ),
                              const SizedBox(width: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AdminTheme.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AdminTheme.primary.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  log.action,
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AdminTheme.primaryLight),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'By ${log.adminName}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textWhite),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  log.details,
                                  style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                                ),
                              ),
                              Text(
                                log.ipAddress,
                                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AdminTheme.textSubtle),
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
