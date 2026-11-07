import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/customer.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/customer_provider.dart';
import '../../providers/shop_provider.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
      if (shop != null) {
        Provider.of<CustomerProvider>(context, listen: false).loadCustomers(shop.id);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddEditCustomerDialog({Customer? customer}) {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final addressCtrl = TextEditingController(text: customer?.address ?? '');
    final gstinCtrl = TextEditingController(text: customer?.gstin ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer == null ? 'Add Customer' : 'Edit Customer'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Customer Name *')),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number')),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 12),
              TextField(controller: gstinCtrl, decoration: const InputDecoration(labelText: 'VAT / TRN Number')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final shop = Provider.of<ShopProvider>(context, listen: false).currentShop!;
              final newCust = Customer(
                id: customer?.id ?? const Uuid().v4(),
                shopId: shop.id,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                gstin: gstinCtrl.text.trim().toUpperCase(),
                creditBalance: customer?.creditBalance ?? 0.0,
              );
              await Provider.of<CustomerProvider>(context, listen: false).saveCustomer(newCust);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCollectPaymentDialog(Customer customer) {
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Collect Payment: ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Due Balance: ${currency.format(customer.creditBalance)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount Received (Rs.) *',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            onPressed: () async {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amt <= 0) return;
              final shop = Provider.of<ShopProvider>(context, listen: false).currentShop!;
              await Provider.of<CustomerProvider>(context, listen: false).updateCreditBalance(
                customer.id,
                -amt, // reduce balance
                shop.id,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);

    final filtered = customerProvider.customers.where((c) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.phone.contains(q) || c.gstin.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers & Udhar (Credit)'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () => _showAddEditCustomerDialog(),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search customer by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: customerProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No customers added yet.\nTap "+" to add a customer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, index) {
                          final c = filtered[index];
                          final hasDue = c.creditBalance > 0;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withAlpha(20),
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ),
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${c.phone.isNotEmpty ? c.phone : "No Phone"} ${c.gstin.isNotEmpty ? " | VAT: ${c.gstin}" : ""}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        hasDue ? currency.format(c.creditBalance) : 'No Due',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: hasDue ? AppTheme.danger : AppTheme.success,
                                        ),
                                      ),
                                      if (hasDue)
                                        const Text('Udhar (Due)', style: TextStyle(fontSize: 10, color: AppTheme.danger)),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  if (hasDue)
                                    IconButton(
                                      icon: const Icon(Icons.payments, color: AppTheme.success),
                                      tooltip: 'Collect Due Payment',
                                      onPressed: () => _showCollectPaymentDialog(c),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: AppTheme.textSecondary, size: 20),
                                    onPressed: () => _showAddEditCustomerDialog(customer: c),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
