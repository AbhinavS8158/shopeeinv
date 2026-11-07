import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/database/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/billing_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import '../auth/shop_setup_screen.dart';
import '../auth/sign_in_screen.dart';
import '../../providers/auth_provider.dart';

class ShopSettingsScreen extends StatefulWidget {
  const ShopSettingsScreen({super.key});

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  bool _isSyncing = false;

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    final success = await SyncService.instance.syncAll();
    setState(() => _isSyncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Sync completed successfully!' : 'Sync failed: ${SyncService.instance.syncError ?? "No network / Firebase not configured"}'),
          backgroundColor: success ? AppTheme.success : AppTheme.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context);
    final currentShop = shopProvider.currentShop;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Settings & Multi-Shop'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Shop Card
                if (currentShop != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentShop.shopName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text('Owner: ${currentShop.ownerName} | Ph: ${currentShop.phone}'),
                                  if (currentShop.gstin.isNotEmpty)
                                    Text('VAT / TRN: ${currentShop.gstin}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ShopSetupScreen(existingShop: currentShop)),
                                  );
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Text('Address: ${currentShop.address}, ${currentShop.city}, ${currentShop.state}'),
                          if (currentShop.upiId.isNotEmpty)
                            Text('UPI ID: ${currentShop.upiId}'),
                          Text('Invoice Prefix: ${currentShop.invoicePrefix} | Format: ${currentShop.defaultInvoiceType.toUpperCase()}'),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                // Multi-Shop Switcher Section
                _buildHeader('Multi-Shop Management'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.add_business, color: AppTheme.primary),
                        title: const Text('Add Another Shop / Branch', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Create an isolated profile for another store'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ShopSetupScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ...shopProvider.shops.map((s) {
                        final isSelected = s.id == currentShop?.id;
                        return ListTile(
                          leading: Icon(
                            isSelected ? Icons.check_circle : Icons.store,
                            color: isSelected ? AppTheme.success : AppTheme.textSecondary,
                          ),
                          title: Text(s.shopName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          subtitle: Text('VAT / TRN: ${s.gstin.isNotEmpty ? s.gstin : "N/A"}'),
                          trailing: isSelected
                              ? const Chip(label: Text('ACTIVE', style: TextStyle(fontSize: 10, color: AppTheme.success)))
                              : TextButton(
                                  onPressed: () async {
                                    await shopProvider.switchShop(s.id);
                                    if (mounted) {
                                      Provider.of<ProductProvider>(context, listen: false).loadProducts(s.id);
                                      Provider.of<BillingProvider>(context, listen: false).loadInvoices(s.id);
                                      Provider.of<CustomerProvider>(context, listen: false).loadCustomers(s.id);
                                    }
                                  },
                                  child: const Text('Switch'),
                                ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Cloud Sync Section (Firebase & Offline SQLite)
                _buildHeader('Offline Database & Firebase Cloud Sync'),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: SyncService.instance.onlineNotifier,
                          builder: (_, isOnline, __) => Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline ? AppTheme.success : AppTheme.warning,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOnline ? 'Device is Online' : 'Device is Offline (sqflite Local Storage Active)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isOnline ? AppTheme.success : AppTheme.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<int>(
                          valueListenable: SyncService.instance.pendingNotifier,
                          builder: (_, pending, __) => Text(
                            'Pending unsynced records: $pending',
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                        if (SyncService.instance.lastSyncTime != null)
                          Text(
                            'Last Sync: ${DateFormat('dd/MM/yyyy hh:mm a').format(SyncService.instance.lastSyncTime!)}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isSyncing
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.sync),
                            label: const Text('SYNC NOW TO FIREBASE CLOUD'),
                            onPressed: _isSyncing ? null : _triggerManualSync,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Account, License & Logout Section
                _buildHeader('Account & License Management'),
                const SizedBox(height: 8),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    final user = auth.currentUser;
                    final lic = auth.currentLicense;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryLight,
                                child: Text(
                                  (user != null && user.name.isNotEmpty) ? user.name[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(user?.name ?? 'User Account', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(user?.email ?? 'No email associated'),
                              trailing: Chip(
                                label: Text(
                                  lic?.status.toUpperCase() ?? 'ACTIVE',
                                  style: const TextStyle(fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const Divider(height: 16),
                            if (lic != null) ...[
                              Text('License Key: ' + lic.licenseKey, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Terminal Capacity: Up to ' + lic.maxDevices.toString() + ' active devices', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              if (lic.expiresAt != null)
                                Text('Valid Until: ' + DateFormat('dd/MM/yyyy').format(lic.expiresAt!), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              const SizedBox(height: 16),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.logout, color: AppTheme.danger),
                                label: const Text('LOGOUT FROM THIS DEVICE', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.danger),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Row(
                                        children: [
                                          Icon(Icons.logout, color: AppTheme.danger),
                                          SizedBox(width: 8),
                                          Text('Confirm Sign Out'),
                                        ],
                                      ),
                                      content: const Text('Are you sure you want to log out of ShopeeInv on this device?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await auth.logout();
                                            if (context.mounted) {
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(builder: (_) => const SignInScreen()),
                                                (route) => false,
                                              );
                                            }
                                          },
                                          child: const Text('Sign Out'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
    );
  }
}
