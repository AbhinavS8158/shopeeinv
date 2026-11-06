import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';
import '../../widgets/confirmation_dialog.dart';

class DeviceListScreen extends StatefulWidget {
  final VoidCallback onOpenSimulator;

  const DeviceListScreen({super.key, required this.onOpenSimulator});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _platformFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();

    final filtered = service.devices.where((d) {
      final customerName = service.getCustomerName(d.customerId).toLowerCase();
      final matchesQuery = _searchQuery.isEmpty ||
          d.deviceName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.deviceId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.operatingSystem.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          customerName.contains(_searchQuery.toLowerCase());

      final matchesStatus = _statusFilter == 'ALL' || d.status == _statusFilter;
      final matchesPlatform = _platformFilter == 'ALL' || d.deviceType == _platformFilter;

      return matchesQuery && matchesStatus && matchesPlatform;
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
                    'Connected Device Fleet',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textWhite, letterSpacing: -0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Real-time hardware inventory, slot allocation, device blacklisting, and remote deactivation.',
                    style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenSimulator,
                icon: const Icon(Icons.phone_android, size: 16, color: AdminTheme.primaryLight),
                label: const Text('Device Simulator', style: TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.primaryLight)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AdminTheme.primary.withValues(alpha: 0.4)),
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
                      hintText: 'Search by device name, hardware UUID, shop name, or OS...',
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
                        DropdownMenuItem(value: 'Blocked', child: Text('Blocked')),
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
                      value: _platformFilter,
                      dropdownColor: AdminTheme.panelBg,
                      style: const TextStyle(fontSize: 13, color: AdminTheme.textWhite),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Types')),
                        DropdownMenuItem(value: 'Desktop', child: Text('Desktop')),
                        DropdownMenuItem(value: 'Laptop', child: Text('Laptop')),
                        DropdownMenuItem(value: 'Mobile', child: Text('Mobile')),
                        DropdownMenuItem(value: 'Tablet', child: Text('Tablet')),
                      ],
                      onChanged: (v) => setState(() => _platformFilter = v ?? 'ALL'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Devices Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.panelBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
              ),
              child: filtered.isEmpty
                  ? const Center(child: Text('No devices registered.', style: TextStyle(color: AdminTheme.textMuted)))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B), height: 1),
                        itemBuilder: (context, index) {
                          final d = filtered[index];
                          final customerName = service.getCustomerName(d.customerId);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.info.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    d.deviceType == 'Mobile' ? Icons.phone_android : (d.deviceType == 'Tablet' ? Icons.tablet : Icons.laptop_mac),
                                    size: 20,
                                    color: AdminTheme.info,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.deviceName,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdminTheme.textWhite),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Customer: $customerName',
                                        style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.deviceId,
                                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AdminTheme.primaryLight),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${d.operatingSystem} • v${d.appVersion}',
                                        style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: d.status == 'Active' ? AdminTheme.success.withValues(alpha: 0.15) : AdminTheme.danger.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    d.status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: d.status == 'Active' ? AdminTheme.success : AdminTheme.danger,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Text(
                                  DateFormat('dd MMM, HH:mm').format(d.lastActiveAt),
                                  style: const TextStyle(fontSize: 12, color: AdminTheme.textSubtle),
                                ),
                                const SizedBox(width: 14),
                                IconButton(
                                  icon: Icon(
                                    d.status == 'Blocked' ? Icons.lock_open : Icons.block,
                                    size: 18,
                                    color: d.status == 'Blocked' ? AdminTheme.success : AdminTheme.warning,
                                  ),
                                  tooltip: d.status == 'Blocked' ? 'Unblock Device' : 'Block Device',
                                  onPressed: () {
                                    if (d.status == 'Blocked') {
                                      service.unblockDevice(d.id);
                                    } else {
                                      service.blockDevice(d.id);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AdminTheme.danger),
                                  tooltip: 'Deactivate Device (Frees Slot Immediately)',
                                  onPressed: () async {
                                    final confirm = await ConfirmationDialog.show(
                                      context: context,
                                      title: 'Deactivate Device?',
                                      message: 'Are you sure you want to deactivate "${d.deviceName}"? This device will be disconnected and its slot freed up immediately.',
                                      confirmText: 'Deactivate & Free Slot',
                                    );
                                    if (confirm) {
                                      service.deactivateDevice(d.id);
                                    }
                                  },
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
