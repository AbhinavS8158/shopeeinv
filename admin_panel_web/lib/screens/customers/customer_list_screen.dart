import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/license_model.dart';
import '../../core/theme/admin_theme.dart';
import '../../services/license_service.dart';
import '../../widgets/confirmation_dialog.dart';
import 'customer_details_dialog.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  String _searchQuery = '';
  String _selectedStatus = 'ALL';

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LicenseService>();

    final filtered = service.customers.where((c) {
      final matchesQuery = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.shopName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.phone.contains(_searchQuery) ||
          c.customerCode.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatus == 'ALL' || c.status == _selectedStatus;

      return matchesQuery && matchesStatus;
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
                    'Customer Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AdminTheme.textWhite, letterSpacing: -0.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage registered shop owners, assigned licenses, and authorized POS devices.',
                    style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddCustomerDialog(context),
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('Add Customer', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search and Filters
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
                      hintText: 'Search by shop name, owner, email, phone, or code...',
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
                      value: _selectedStatus,
                      dropdownColor: AdminTheme.panelBg,
                      style: const TextStyle(fontSize: 13, color: AdminTheme.textWhite),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                        DropdownMenuItem(value: 'Active', child: Text('Active')),
                        DropdownMenuItem(value: 'Blocked', child: Text('Blocked')),
                      ],
                      onChanged: (v) => setState(() => _selectedStatus = v ?? 'ALL'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customers Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AdminTheme.panelBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AdminTheme.borderColor.withValues(alpha: 0.6)),
              ),
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No customers found.', style: TextStyle(color: AdminTheme.textMuted)),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B), height: 1),
                        itemBuilder: (context, index) {
                          final c = filtered[index];
                          final lic = service.licenses.firstWhere(
                            (l) => l.customerId == c.id,
                            orElse: () => LicenseModel(
                              id: '',
                              licenseKey: 'None',
                              customerId: '',
                              customerName: '',
                              issuedAt: DateTime.now(),
                            ),
                          );
                          final activeDevCount = service.devices.where((d) => d.customerId == c.id && d.status == 'Active').length;
                          final maxDev = lic.id.isNotEmpty ? lic.maxDevices : 2;
                          final isLimitFull = activeDevCount >= maxDev;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AdminTheme.primary.withValues(alpha: 0.2),
                                  child: Text(
                                    c.shopName.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: AdminTheme.primaryLight, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.shopName,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AdminTheme.textWhite),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c.name} • ${c.email}',
                                        style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                                      ),
                                      Text(
                                        c.customerCode,
                                        style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AdminTheme.textSubtle),
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
                                        lic.id.isNotEmpty ? lic.licenseKey : 'No license',
                                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: AdminTheme.primaryLight),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        lic.id.isNotEmpty ? '${lic.licenseType} • ${lic.effectiveStatus}' : 'Unassigned',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: lic.effectiveStatus == 'Active' ? AdminTheme.success : AdminTheme.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '$activeDevCount / $maxDev devices',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isLimitFull ? AdminTheme.danger : AdminTheme.textWhite,
                                            ),
                                          ),
                                          if (isLimitFull) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                              decoration: BoxDecoration(color: AdminTheme.danger.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                              child: const Text('FULL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AdminTheme.danger)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 120,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: maxDev > 0 ? (activeDevCount / maxDev).clamp(0.0, 1.0) : 0,
                                            backgroundColor: AdminTheme.scaffoldBg,
                                            valueColor: AlwaysStoppedAnimation<Color>(isLimitFull ? AdminTheme.danger : AdminTheme.success),
                                            minHeight: 5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: c.status == 'Active' ? AdminTheme.success.withValues(alpha: 0.15) : AdminTheme.danger.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    c.status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: c.status == 'Active' ? AdminTheme.success : AdminTheme.danger,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                IconButton(
                                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: AdminTheme.textMuted),
                                  tooltip: 'Customer Profile',
                                  onPressed: () => CustomerDetailsDialog.show(context, c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18, color: AdminTheme.warning),
                                  tooltip: 'Reset Devices',
                                  onPressed: () async {
                                    final confirm = await ConfirmationDialog.show(
                                      context: context,
                                      title: 'Reset Devices for ${c.shopName}?',
                                      message: 'This will disconnect all currently registered devices and free all device slots for this customer.',
                                      confirmText: 'Reset Devices',
                                      confirmColor: AdminTheme.warning,
                                    );
                                    if (confirm) {
                                      service.resetCustomerDevices(c.id);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: Icon(
                                    c.status == 'Blocked' ? Icons.lock_open : Icons.block,
                                    size: 18,
                                    color: c.status == 'Blocked' ? AdminTheme.success : AdminTheme.danger,
                                  ),
                                  tooltip: c.status == 'Blocked' ? 'Unblock Customer' : 'Block Customer',
                                  onPressed: () => service.toggleCustomerStatus(c.id),
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

  void _showAddCustomerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final shopNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    bool issueLicense = true;
    String tier = 'Standard';
    String validity = '1_year';
    int devices = 2;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: AdminTheme.panelBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AdminTheme.borderColor)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Register New Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.textWhite)),
                  const SizedBox(height: 16),
                  TextField(controller: shopNameCtrl, decoration: const InputDecoration(labelText: 'Shop / Company Name *')),
                  const SizedBox(height: 12),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Owner Full Name *')),
                  const SizedBox(height: 12),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address *')),
                  const SizedBox(height: 12),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
                  const SizedBox(height: 12),
                  TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Shop Address')),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Automatically issue license key', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminTheme.primaryLight)),
                    value: issueLicense,
                    onChanged: (v) => setModalState(() => issueLicense = v),
                  ),
                  if (issueLicense) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: tier,
                            decoration: const InputDecoration(labelText: 'License Tier'),
                            items: const [
                              DropdownMenuItem(value: 'Standard', child: Text('Standard')),
                              DropdownMenuItem(value: 'Premium', child: Text('Premium')),
                              DropdownMenuItem(value: 'Enterprise', child: Text('Enterprise')),
                              DropdownMenuItem(value: 'Trial', child: Text('Trial')),
                            ],
                            onChanged: (v) => setModalState(() => tier = v ?? 'Standard'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: validity,
                            decoration: const InputDecoration(labelText: 'Validity'),
                            items: const [
                              DropdownMenuItem(value: '1_year', child: Text('1 Year')),
                              DropdownMenuItem(value: '30_days', child: Text('30 Days')),
                              DropdownMenuItem(value: '3_months', child: Text('3 Months')),
                              DropdownMenuItem(value: '6_months', child: Text('6 Months')),
                              DropdownMenuItem(value: 'lifetime', child: Text('Lifetime')),
                            ],
                            onChanged: (v) => setModalState(() => validity = v ?? '1_year'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Device Quota: ', style: TextStyle(color: AdminTheme.textMuted, fontSize: 13)),
                        const SizedBox(width: 10),
                        for (final d in [1, 2, 3, 5, 10])
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('$d'),
                              selected: devices == d,
                              onSelected: (_) => setModalState(() => devices = d),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (shopNameCtrl.text.isEmpty || nameCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                          context.read<LicenseService>().addCustomer(
                                name: nameCtrl.text.trim(),
                                shopName: shopNameCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                address: addressCtrl.text.trim(),
                                issueLicense: issueLicense,
                                licenseTier: tier,
                                validityType: validity,
                                maxDevices: devices,
                              );
                          Navigator.pop(ctx);
                        },
                        child: const Text('Create Customer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
