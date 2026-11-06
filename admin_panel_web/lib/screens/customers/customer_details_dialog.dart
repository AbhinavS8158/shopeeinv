import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/customer_model.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';

class CustomerDetailsDialog extends StatelessWidget {
  final CustomerModel customer;

  const CustomerDetailsDialog({super.key, required this.customer});

  static void show(BuildContext context, CustomerModel customer) {
    showDialog(
      context: context,
      builder: (ctx) => CustomerDetailsDialog(customer: customer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final lic = service.licenses.firstWhere(
      (l) => l.customerId == customer.id,
      orElse: () => service.licenses.isNotEmpty ? service.licenses.first : service.licenses.first,
    );
    final devices = service.devices.where((d) => d.customerId == customer.id).toList();

    return Dialog(
      backgroundColor: AdminTheme.panelBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdminTheme.borderColor)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                        child: Text(
                          customer.shopName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: AdminTheme.primaryLight, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                          Text('${customer.name} • ${customer.customerCode}', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close, color: AdminTheme.textMuted), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 20),

              // Customer Info Grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoColumn('EMAIL', customer.email),
                    _buildInfoColumn('PHONE', customer.phone.isNotEmpty ? customer.phone : 'Not provided'),
                    _buildInfoColumn('STATUS', customer.status, color: customer.status == 'Active' ? AdminTheme.success : AdminTheme.danger),
                    _buildInfoColumn('REGISTERED', DateFormat('dd MMM yyyy').format(customer.createdAt)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Active License Section
              const Text('Assigned Software License', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('LICENSE KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.textSubtle)),
                            Text(lic.licenseKey, style: const TextStyle(fontSize: 15, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AdminTheme.primaryLight)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: lic.effectiveStatus == 'Active' ? AdminTheme.success.withValues(alpha: 0.15) : AdminTheme.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(lic.effectiveStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: lic.effectiveStatus == 'Active' ? AdminTheme.success : AdminTheme.danger)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tier: ${lic.licenseType}', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                        Text('Limit: ${devices.length} / ${lic.maxDevices} devices', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                        Text('Expires: ${lic.expiresAt != null ? DateFormat('dd MMM yyyy').format(lic.expiresAt!) : 'Lifetime'}', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Connected Devices List
              Text('Connected Fleet (${devices.length} devices)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
              const SizedBox(height: 8),
              if (devices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(color: AdminTheme.cardBg, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('No devices registered under this account.', style: TextStyle(color: AdminTheme.textMuted, fontSize: 12))),
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
                            size: 20,
                            color: AdminTheme.info,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(d.deviceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.textWhite)),
                                Text('${d.deviceId} • ${d.operatingSystem}', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: d.status == 'Active' ? AdminTheme.success.withValues(alpha: 0.15) : AdminTheme.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(d.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: d.status == 'Active' ? AdminTheme.success : AdminTheme.danger)),
                          ),
                          const SizedBox(width: 8),
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

  Widget _buildInfoColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AdminTheme.textSubtle)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? AdminTheme.textWhite)),
      ],
    );
  }
}
