import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _deviceLimitCtrl;
  late TextEditingController _trialDaysCtrl;
  late TextEditingController _minVersionCtrl;
  late bool _allowDereg;

  @override
  void initState() {
    super.initState();
    final service = context.read<LicenseService>();
    _deviceLimitCtrl = TextEditingController(text: '${service.defaultDeviceLimit}');
    _trialDaysCtrl = TextEditingController(text: '${service.defaultTrialDays}');
    _minVersionCtrl = TextEditingController(text: service.minAppVersion);
    _allowDereg = service.allowDeviceDeregistration;
  }

  @override
  void dispose() {
    _deviceLimitCtrl.dispose();
    _trialDaysCtrl.dispose();
    _minVersionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'System Administration & Policies',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textWhite, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              const Text(
                'Configure global license policies, hardware limits, and system backups.',
                style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
              ),
              const SizedBox(height: 24),

              // Firebase Backend Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AdminTheme.primary.withValues(alpha: 0.15),
                      AdminTheme.panelBg.withValues(alpha: 0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminTheme.primary.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Firebase Cloud Backend',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AdminTheme.success.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: AdminTheme.success),
                              SizedBox(width: 5),
                              Text('LIVE CONNECTED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AdminTheme.success)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'All customer profiles, licenses, device bindings, and connection histories are stored and synchronized in real time with Cloud Firestore.',
                      style: TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminTheme.scaffoldBg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminTheme.borderColor),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Project ID: ', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                              Text('shopeeinv-8da75', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.primaryLight)),
                              SizedBox(width: 14),
                              Text('Database: ', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                              Text('(default)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.success)),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Firebase Account: ', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                              Text('abhinav.8158s@gmail.com', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminTheme.textWhite)),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            children: [
                              Text('Firestore Collections: ', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                              Text('customers, licenses, devices, activity_logs, connection_history', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AdminTheme.textWhite)),
                            ],
                          ),
                          SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Database URL: ', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                              Expanded(
                                child: Text('https://console.firebase.google.com/project/shopeeinv-8da75/firestore/databases/-default-/data', style: TextStyle(fontSize: 11, color: AdminTheme.info)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Global Licensing Policy Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AdminTheme.panelBg.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Global Licensing Policy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                    const SizedBox(height: 6),
                    const Text('Default settings applied when issuing new software licenses.', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _deviceLimitCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Default Device Limit per License'),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _trialDaysCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Default Trial Duration (Days)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: _minVersionCtrl,
                      decoration: const InputDecoration(labelText: 'Minimum Client App Version Required'),
                    ),
                    const SizedBox(height: 14),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Allow Client Device Deregistration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.textWhite)),
                      subtitle: const Text('When enabled, shop owners can remove old devices from inside the POS app to free slots.', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                      value: _allowDereg,
                      onChanged: (v) => setState(() => _allowDereg = v),
                    ),
                    const SizedBox(height: 18),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () {
                          service.defaultDeviceLimit = int.tryParse(_deviceLimitCtrl.text) ?? 2;
                          service.defaultTrialDays = int.tryParse(_trialDaysCtrl.text) ?? 14;
                          service.minAppVersion = _minVersionCtrl.text.trim();
                          service.allowDeviceDeregistration = _allowDereg;

                          service.logAdminActivity(
                            action: 'UPDATE_SETTINGS',
                            targetType: 'SYSTEM',
                            targetId: 'GLOBAL',
                            details: 'Updated default device limit to ${service.defaultDeviceLimit}',
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings saved successfully!'), duration: Duration(seconds: 2)),
                          );
                        },
                        child: const Text('Save Policy Settings'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Database & Backup Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AdminTheme.panelBg.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminTheme.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Data Export & Backup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                    const SizedBox(height: 6),
                    const Text('Download full JSON backup of customers, licenses, registered hardware, and connection logs.', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                    const SizedBox(height: 20),

                    OutlinedButton.icon(
                      onPressed: () {
                        final data = {
                          'exportTimestamp': DateTime.now().toIso8601String(),
                          'customers': service.customers.map((c) => c.toMap()).toList(),
                          'licenses': service.licenses.map((l) => l.toMap()).toList(),
                          'devices': service.devices.map((d) => d.toMap()).toList(),
                          'activityLogs': service.activityLogs.map((l) => l.toMap()).toList(),
                        };
                        final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            backgroundColor: AdminTheme.panelBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: AdminTheme.borderColor)),
                            child: Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Backup Generated', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                                  const SizedBox(height: 8),
                                  const Text('JSON dump generated successfully. Copy or save:', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                                  const SizedBox(height: 12),
                                  Container(
                                    height: 200,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: AdminTheme.scaffoldBg, borderRadius: BorderRadius.circular(10)),
                                    child: SingleChildScrollView(
                                      child: Text(jsonStr, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AdminTheme.primaryLight)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export JSON Database Backup'),
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
