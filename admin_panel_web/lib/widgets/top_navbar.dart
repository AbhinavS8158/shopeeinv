import 'package:flutter/material.dart';
import '../core/theme/admin_theme.dart';

class TopNavbar extends StatelessWidget {
  final VoidCallback onOpenMenu;
  final VoidCallback onOpenSimulator;
  final VoidCallback onIssueLicense;

  const TopNavbar({
    super.key,
    required this.onOpenMenu,
    required this.onOpenSimulator,
    required this.onIssueLicense,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AdminTheme.sidebarBg.withValues(alpha: 0.8),
        border: const Border(bottom: BorderSide(color: AdminTheme.borderColor)),
      ),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AdminTheme.textWhite),
              onPressed: onOpenMenu,
            ),
            const SizedBox(width: 8),
          ],

          // Firebase Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AdminTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AdminTheme.primary.withValues(alpha: 0.35)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_done, size: 13, color: AdminTheme.primaryLight),
                SizedBox(width: 6),
                Text(
                  'Firestore: (default) • shopeeinv-8da75',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.primaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Server Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AdminTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AdminTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AdminTheme.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Licensing Core Online',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AdminTheme.success,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Simulator Shortcut
          OutlinedButton.icon(
            onPressed: onOpenSimulator,
            icon: const Icon(Icons.phone_android, size: 16, color: AdminTheme.primaryLight),
            label: const Text(
              'Test Device Limits',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.primaryLight),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AdminTheme.primary.withValues(alpha: 0.4)),
              backgroundColor: AdminTheme.primary.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 12),

          // Issue License Button
          ElevatedButton.icon(
            onPressed: onIssueLicense,
            icon: const Icon(Icons.add, size: 16),
            label: const Text(
              'Issue License',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
