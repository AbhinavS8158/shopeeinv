import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/license_model.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';

class LicenseDetailsScreen extends StatelessWidget {
  final LicenseModel license;

  const LicenseDetailsScreen({super.key, required this.license});

  static void show(BuildContext context, LicenseModel license) {
    showDialog(
      context: context,
      builder: (ctx) => LicenseDetailsScreen(license: license),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final devices = service.devices.where((d) => d.licenseId == license.id).toList();
    final isFull = devices.length >= license.maxDevices;

    return Dialog(
      backgroundColor: AdminTheme.panelBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdminTheme.borderColor)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('License Key Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                  IconButton(icon: const Icon(Icons.close, color: AdminTheme.textMuted), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 18),

              // QR Code and Key Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(
                        data: license.licenseKey,
                        version: QrVersions.auto,
                        size: 96,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                license.licenseKey,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w800,
                                  color: AdminTheme.primaryLight,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16, color: AdminTheme.textMuted),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: license.licenseKey));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Copied key to clipboard!'), duration: Duration(seconds: 1)),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Customer: ${license.customerName}', style: const TextStyle(fontSize: 13, color: AdminTheme.textWhite)),
                          const SizedBox(height: 2),
                          Text('Tier: ${license.licenseType} • Status: ${license.effectiveStatus}', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                          const SizedBox(height: 6),
                          const Text(
                            'Scan QR code from ShopeeInv Mobile / Desktop to activate',
                            style: TextStyle(fontSize: 10, color: AdminTheme.textSubtle),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Device Quota Meter
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hardware Device Quota', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                        Text(
                          '${devices.length} of ${license.maxDevices} Slots Occupied',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isFull ? AdminTheme.danger : AdminTheme.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: license.maxDevices > 0 ? (devices.length / license.maxDevices).clamp(0.0, 1.0) : 0,
                        backgroundColor: AdminTheme.scaffoldBg,
                        valueColor: AlwaysStoppedAnimation<Color>(isFull ? AdminTheme.danger : AdminTheme.success),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Registered Devices Table
              Text('Connected Devices (${devices.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
              const SizedBox(height: 8),
              if (devices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(color: AdminTheme.cardBg, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('No devices have connected using this key yet.', style: TextStyle(color: AdminTheme.textMuted, fontSize: 12))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: devices.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final d = devices[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminTheme.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AdminTheme.borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            d.deviceType == 'Mobile' ? Icons.phone_android : Icons.laptop_mac,
                            size: 18,
                            color: AdminTheme.info,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.deviceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.textWhite)),
                                Text('ID: ${d.deviceId} • ${d.operatingSystem}', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                              ],
                            ),
                          ),
                          Text(
                            DateFormat('dd MMM, HH:mm').format(d.lastActiveAt),
                            style: const TextStyle(fontSize: 10, color: AdminTheme.textSubtle),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AdminTheme.danger),
                            tooltip: 'Deactivate Device (Frees Slot)',
                            onPressed: () => service.deactivateDevice(d.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
