import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';

class DeviceSimulatorScreen extends StatefulWidget {
  const DeviceSimulatorScreen({super.key});

  @override
  State<DeviceSimulatorScreen> createState() => _DeviceSimulatorScreenState();
}

class _DeviceSimulatorScreenState extends State<DeviceSimulatorScreen> {
  final _keyCtrl = TextEditingController(text: 'POS-ABCD-1234-EFGH');
  final _devIdCtrl = TextEditingController(text: 'dev_win_counter_1');
  final _devNameCtrl = TextEditingController(text: 'Device 1 (Main Billing Counter)');
  String _deviceType = 'Desktop';
  String _os = 'Windows 11 Pro';
  final String _version = '1.0.0+1';

  SimulateLoginResult? _lastResult;

  @override
  void dispose() {
    _keyCtrl.dispose();
    _devIdCtrl.dispose();
    _devNameCtrl.dispose();
    super.dispose();
  }

  void _loadPreset(String preset) {
    _keyCtrl.text = 'POS-ABCD-1234-EFGH';

    if (preset == 'device1') {
      _devIdCtrl.text = 'dev_win_counter_1';
      _devNameCtrl.text = 'Device 1 (Main Billing Counter)';
      _deviceType = 'Desktop';
      _os = 'Windows 11 Pro';
    } else if (preset == 'device2') {
      _devIdCtrl.text = 'dev_win_counter_2';
      _devNameCtrl.text = 'Device 2 (Second Billing Counter)';
      _deviceType = 'Desktop';
      _os = 'Windows 10 Enterprise';
    } else if (preset == 'device3') {
      _devIdCtrl.text = 'dev_mob_samsung_3';
      _devNameCtrl.text = 'Device 3 (Third Mobile POS)';
      _deviceType = 'Mobile';
      _os = 'Android 14';
    }
    setState(() {});
    _executeTest();
  }

  void _executeTest() {
    final service = context.read<LicenseService>();
    final result = service.simulateClientLogin(
      licenseKey: _keyCtrl.text.trim(),
      deviceId: _devIdCtrl.text.trim(),
      deviceName: _devNameCtrl.text.trim(),
      deviceType: _deviceType,
      operatingSystem: _os,
      appVersion: _version,
    );

    setState(() {
      _lastResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();
    final abcLic = service.licenses.firstWhere(
      (l) => l.licenseKey == 'POS-ABCD-1234-EFGH',
      orElse: () => service.licenses.isNotEmpty ? service.licenses.first : service.licenses.first,
    );
    final abcDevices = service.devices.where((d) => d.licenseId == abcLic.id && d.status == 'Active').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Interactive Client Device Simulator',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textWhite, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          const Text(
            'Test live hardware telemetry, 2-device limit enforcement, slot occupancy, and rejection handling.',
            style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
          ),
          const SizedBox(height: 20),

          // Preset Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AdminTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
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
                        Icon(Icons.bolt, color: AdminTheme.primaryLight, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Test Scenario: ABC Supermarket (2-Device Quota)',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.primaryLight),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: abcDevices.length >= abcLic.maxDevices ? AdminTheme.danger.withValues(alpha: 0.2) : AdminTheme.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Slots: ${abcDevices.length} / ${abcLic.maxDevices} occupied',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: abcDevices.length >= abcLic.maxDevices ? AdminTheme.danger : AdminTheme.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Click the buttons below to simulate login from each device. Device 1 and Device 2 will connect successfully. Device 3 will be BLOCKED because the 2-device quota is filled!',
                  style: TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _loadPreset('device1'),
                      icon: const Icon(Icons.laptop, size: 16),
                      label: const Text('Simulate Device 1 (Billing PC)'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _loadPreset('device2'),
                      icon: const Icon(Icons.laptop, size: 16),
                      label: const Text('Simulate Device 2 (Counter 2)'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _loadPreset('device3'),
                      icon: const Icon(Icons.phone_android, size: 16),
                      label: const Text('Simulate Device 3 (Third Device - BLOCKED)'),
                      style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.danger),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Main 2-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Request payload controls (Expanded flex 6)
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AdminTheme.panelBg.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Client Request Parameters', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                      const SizedBox(height: 16),
                      TextField(controller: _keyCtrl, decoration: const InputDecoration(labelText: 'License Key (POS-XXXX-XXXX-XXXX)')),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _devIdCtrl, decoration: const InputDecoration(labelText: 'Hardware UUID / Device ID'))),
                          const SizedBox(width: 12),
                          Expanded(child: TextField(controller: _devNameCtrl, decoration: const InputDecoration(labelText: 'Device Name'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _deviceType,
                              dropdownColor: AdminTheme.panelBg,
                              decoration: const InputDecoration(labelText: 'Device Type'),
                              items: const [
                                DropdownMenuItem(value: 'Desktop', child: Text('Desktop')),
                                DropdownMenuItem(value: 'Laptop', child: Text('Laptop')),
                                DropdownMenuItem(value: 'Mobile', child: Text('Mobile')),
                                DropdownMenuItem(value: 'Tablet', child: Text('Tablet')),
                              ],
                              onChanged: (v) => setState(() => _deviceType = v ?? 'Desktop'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: TextEditingController(text: _os),
                              decoration: const InputDecoration(labelText: 'Operating System'),
                              onChanged: (v) => _os = v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _executeTest,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Execute Hardware Authentication', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Right: Simulated POS Screen Outcome (Expanded flex 5)
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AdminTheme.panelBg.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AdminTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Simulated Client Screen', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                          if (_lastResult != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _lastResult!.allowed ? AdminTheme.success.withValues(alpha: 0.15) : AdminTheme.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_lastResult!.statusCode} ${_lastResult!.allowed ? "OK" : "FORBIDDEN"}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _lastResult!.allowed ? AdminTheme.success : AdminTheme.danger,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Screen Box
                      Container(
                        padding: const EdgeInsets.all(24),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AdminTheme.scaffoldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _lastResult == null
                                ? AdminTheme.borderColor
                                : (_lastResult!.allowed ? AdminTheme.success.withValues(alpha: 0.4) : AdminTheme.danger.withValues(alpha: 0.4)),
                          ),
                        ),
                        child: _lastResult == null
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Text('Click "Execute Hardware Authentication" or choose a preset above.', style: TextStyle(color: AdminTheme.textMuted, fontSize: 12)),
                                ),
                              )
                            : Column(
                                children: [
                                  Icon(
                                    _lastResult!.allowed ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                    size: 48,
                                    color: _lastResult!.allowed ? AdminTheme.success : AdminTheme.danger,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _lastResult!.allowed ? 'Authentication Granted!' : 'Access Blocked!',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _lastResult!.allowed ? AdminTheme.success : AdminTheme.danger,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _lastResult!.allowed ? AdminTheme.success.withValues(alpha: 0.1) : AdminTheme.danger.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _lastResult!.message,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500,
                                        color: _lastResult!.allowed ? AdminTheme.textWhite : AdminTheme.danger,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  if (_lastResult!.usedSlots != null && _lastResult!.maxSlots != null) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      'Quota: ${_lastResult!.usedSlots} of ${_lastResult!.maxSlots} Device Slots In Use',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.textMuted),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
