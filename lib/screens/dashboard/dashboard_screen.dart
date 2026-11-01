import 'package:flutter/material.dart';
import '../pos/cash_register_dialog.dart';
import '../../providers/cash_register_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/database/sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/billing_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';
import '../customers/customer_list_screen.dart';
import '../inventory/stock_management_screen.dart';
import '../invoices/invoice_history_screen.dart';
import '../pos/invoice_preview_screen.dart';
import '../pos/pos_screen.dart';
import '../products/product_list_screen.dart';
import '../settings/shop_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  final timeFormat = DateFormat('hh:mm a');

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  void _refreshAll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
      if (shop != null) {
        Provider.of<ProductProvider>(context, listen: false).loadProducts(shop.id);
        Provider.of<BillingProvider>(context, listen: false).loadInvoices(shop.id);
        Provider.of<CustomerProvider>(context, listen: false).loadCustomers(shop.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopProvider = Provider.of<ShopProvider>(context);
    final currentShop = shopProvider.currentShop;
    final billingProvider = Provider.of<BillingProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final customerProvider = Provider.of<CustomerProvider>(context);

    final totalDues = customerProvider.customers.fold(0.0, (sum, c) => sum + c.creditBalance);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/icon/app_logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              currentShop?.shopName ?? 'ShopeeInv Billing',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          // Online / Offline Status Pill
          ValueListenableBuilder<bool>(
            valueListenable: SyncService.instance.onlineNotifier,
            builder: (_, isOnline, __) => Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green.shade700 : Colors.orange.shade800,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOnline ? Icons.cloud_done : Icons.cloud_off,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOnline ? 'ONLINE' : 'OFFLINE',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Shop Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopSettingsScreen()),
              ).then((_) => _refreshAll());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.point_of_sale, color: Colors.white),
        label: const Text('NEW BILL (POS)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PosScreen()),
          ).then((_) => _refreshAll());
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshAll();
          await SyncService.instance.syncAll();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Multi-shop quick selector
                  if (shopProvider.shops.length > 1)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Text('Active Shop: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: currentShop?.id,
                              items: shopProvider.shops.map((s) {
                                return DropdownMenuItem(value: s.id, child: Text(s.shopName));
                              }).toList(),
                              onChanged: (id) {
                                if (id != null) {
                                  shopProvider.switchShop(id);
                                  _refreshAll();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Cash Register Daily Summary Banner
                  Consumer<CashRegisterProvider>(
                    builder: (ctx, cashProvider, _) {
                      final session = cashProvider.currentSession;
                      final isOpen = cashProvider.hasOpenSession;
                      final openedAt = session?.openedAt ?? DateTime.now();
                      final sales = billingProvider.getSalesSince(openedAt);
                      final cashSales = billingProvider.getCashSalesSince(openedAt);
                      final opening = session?.openingAmount ?? 0.0;
                      final closingTotal = opening + sales;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green.shade50 : Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOpen ? Colors.green.shade300 : Colors.amber.shade300,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isOpen ? Colors.green.shade100 : Colors.amber.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isOpen ? Icons.point_of_sale : Icons.lock_clock,
                                color: isOpen ? Colors.green.shade800 : Colors.amber.shade900,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        isOpen ? "TODAY'S CASH REGISTER: OPEN" : "CASH REGISTER: CLOSED / NOT OPENED",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isOpen ? Colors.green.shade900 : Colors.amber.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  if (isOpen)
                                    Text(
                                      "Opening: ${currency.format(opening)}  •  Bills: +${currency.format(sales)}  •  Closing Total: ${currency.format(closingTotal)}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade900,
                                      ),
                                    )
                                  else
                                    const Text(
                                      "Tap 'Open Register' to enter opening cash float before starting POS billing.",
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isOpen ? Colors.green.shade700 : AppTheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const CashRegisterDialog(),
                                ).then((_) => _refreshAll());
                              },
                              child: Text(
                                isOpen ? 'VIEW / CLOSE' : 'OPEN REGISTER',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  // Top Metrics Cards
                  _buildMetricsGrid(
                    todaySales: billingProvider.todaySalesAmount,
                    todayCount: billingProvider.todaySalesCount,
                    monthlySales: billingProvider.monthlySalesAmount,
                    totalProducts: productProvider.products.length,
                    lowStockCount: productProvider.lowStockProducts.length,
                    totalCustomers: customerProvider.customers.length,
                    totalDues: totalDues,
                  ),
                  const SizedBox(height: 24),

                  // Quick Actions Bar
                  _buildQuickActionsRow(),
                  const SizedBox(height: 24),

                  // Recent Bills Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Invoices',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_forward, size: 16),
                        label: const Text('View All Invoices'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen()),
                          ).then((_) => _refreshAll());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  billingProvider.invoices.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  const Icon(Icons.receipt_long, size: 48, color: AppTheme.border),
                                  const SizedBox(height: 12),
                                  const Text('No sales bills created yet', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('Tap "NEW BILL (POS)" to create your first bill!',
                                      style: TextStyle(color: AppTheme.textSecondary)),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.point_of_sale),
                                    label: const Text('OPEN POS BILLING'),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const PosScreen()),
                                      ).then((_) => _refreshAll());
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Card(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: billingProvider.recentInvoices.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, index) {
                              final inv = billingProvider.recentInvoices[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primary.withAlpha(20),
                                  child: const Icon(Icons.receipt, color: AppTheme.primary),
                                ),
                                title: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${inv.customerName} • ${DateFormat('dd MMM, hh:mm a').format(inv.invoiceDate)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          currency.format(inv.grandTotal),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primary),
                                        ),
                                        Text(
                                          inv.paymentMode.toUpperCase(),
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.print, color: AppTheme.textSecondary),
                                      tooltip: 'Print / View PDF',
                                      onPressed: () {
                                        if (currentShop != null) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => InvoicePreviewScreen(shop: currentShop, invoice: inv),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid({
    required double todaySales,
    required int todayCount,
    required double monthlySales,
    required int totalProducts,
    required int lowStockCount,
    required int totalCustomers,
    required double totalDues,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : (constraints.maxWidth > 550 ? 2 : 1);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.1,
          children: [
            _buildMetricCard(
              title: "TODAY'S SALES",
              value: currency.format(todaySales),
              subtitle: '$todayCount Bills generated today',
              icon: Icons.today,
              color: AppTheme.primary,
            ),
            _buildMetricCard(
              title: 'THIS MONTH',
              value: currency.format(monthlySales),
              subtitle: 'Current month revenue',
              icon: Icons.calendar_month,
              color: AppTheme.accent,
            ),
            _buildMetricCard(
              title: 'PRODUCTS & STOCK',
              value: '$totalProducts Items',
              subtitle: lowStockCount > 0 ? '$lowStockCount Low stock alerts!' : 'Stock levels healthy',
              icon: Icons.inventory_2,
              color: lowStockCount > 0 ? AppTheme.danger : AppTheme.success,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductListScreen()),
                ).then((_) => _refreshAll());
              },
            ),
            _buildMetricCard(
              title: 'CUSTOMERS & UDHAR',
              value: '$totalCustomers Customers',
              subtitle: totalDues > 0 ? 'Due: ${currency.format(totalDues)}' : 'No pending dues',
              icon: Icons.people,
              color: totalDues > 0 ? AppTheme.warning : AppTheme.primaryDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerListScreen()),
                ).then((_) => _refreshAll());
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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

  Widget _buildQuickActionsRow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Modules',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildActionBtn('POS Billing', Icons.point_of_sale, AppTheme.primary, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PosScreen())).then((_) => _refreshAll());
                }),
                _buildActionBtn('Products', Icons.inventory_2, AppTheme.accent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen())).then((_) => _refreshAll());
                }),
                _buildActionBtn('Stock In', Icons.warehouse, AppTheme.success, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StockManagementScreen())).then((_) => _refreshAll());
                }),
                _buildActionBtn('Invoices', Icons.receipt_long, Colors.purple, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceHistoryScreen())).then((_) => _refreshAll());
                }),
                _buildActionBtn('Customers', Icons.people, Colors.teal, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen())).then((_) => _refreshAll());
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withAlpha(25),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
