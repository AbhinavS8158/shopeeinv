import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';

class DeviceHistoryScreen extends StatefulWidget {
  const DeviceHistoryScreen({super.key});

  @override
  State<DeviceHistoryScreen> createState() => _DeviceHistoryScreenState();
}

class _DeviceHistoryScreenState extends State<DeviceHistoryScreen> {
  String _searchQuery = '';
  String _outcomeFilter = 'ALL';
  String _actionFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();

    final filtered = service.connectionHistory.where((h) {
      final matchesQuery = _searchQuery.isEmpty ||
          h.deviceName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          h.deviceId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          h.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          h.licenseKey.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesOutcome = _outcomeFilter == 'ALL' || h.status == _outcomeFilter;
      final matchesAction = _actionFilter == 'ALL' || h.action == _actionFilter;

      return matchesQuery && matchesOutcome && matchesAction;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Device Connection & Security Log',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textWhite, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete audit trail of every connection, reconnection, and blocked limit rejection.',
            style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
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
                      hintText: 'Search by device name, UUID, customer, or license...',
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
                  decoration: BoxDecoration(color: AdminTheme.scaffoldBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AdminTheme.borderColor)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _outcomeFilter,
                      dropdownColor: AdminTheme.panelBg,
                      style: const TextStyle(fontSize: 13, color: AdminTheme.textWhite),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Outcomes')),
                        DropdownMenuItem(value: 'SUCCESS', child: Text('Allowed (SUCCESS)')),
                        DropdownMenuItem(value: 'DENIED', child: Text('Blocked (DENIED)')),
                      ],
                      onChanged: (v) => setState(() => _outcomeFilter = v ?? 'ALL'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: AdminTheme.scaffoldBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AdminTheme.borderColor)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _actionFilter,
                      dropdownColor: AdminTheme.panelBg,
                      style: const TextStyle(fontSize: 13, color: AdminTheme.textWhite),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Events')),
                        DropdownMenuItem(value: 'CONNECTED', child: Text('New Connected')),
                        DropdownMenuItem(value: 'RECONNECTED', child: Text('Reconnected')),
                        DropdownMenuItem(value: 'BLOCKED_DEVICE_LIMIT', child: Text('Blocked: Device Limit')),
                        DropdownMenuItem(value: 'DEACTIVATED', child: Text('Deactivated')),
                      ],
                      onChanged: (v) => setState(() => _actionFilter = v ?? 'ALL'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // History List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.panelBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
              ),
              child: filtered.isEmpty
                  ? const Center(child: Text('No connection logs recorded.', style: TextStyle(color: AdminTheme.textMuted)))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B), height: 1),
                        itemBuilder: (context, index) {
                          final h = filtered[index];
                          final isDenied = h.status == 'DENIED';

                          return Container(
                            color: isDenied ? AdminTheme.danger.withValues(alpha: 0.05) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(DateFormat('dd MMM yyyy').format(h.timestamp), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                                    Text(DateFormat('HH:mm:ss').format(h.timestamp), style: const TextStyle(fontSize: 10, color: AdminTheme.textSubtle)),
                                  ],
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(h.deviceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                                      Text('${h.deviceId} • ${h.customerName}', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    h.action,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: isDenied ? AdminTheme.danger : AdminTheme.primaryLight,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDenied ? AdminTheme.danger.withValues(alpha: 0.15) : AdminTheme.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    h.status,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDenied ? AdminTheme.danger : AdminTheme.success),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    h.details,
                                    style: TextStyle(fontSize: 12, color: isDenied ? AdminTheme.danger : AdminTheme.textMuted),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
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
}
