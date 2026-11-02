import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/models/daily_register_report_item.dart';
import '../../core/models/invoice.dart';
import '../../core/models/product.dart';
import '../../core/models/shop_profile.dart';
import '../../core/services/register_report_pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/billing_provider.dart';
import '../../providers/cash_register_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/shop_provider.dart';

class CashRegisterHistoryScreen extends StatefulWidget {
  const CashRegisterHistoryScreen({super.key});

  @override
  State<CashRegisterHistoryScreen> createState() => _CashRegisterHistoryScreenState();
}

class _CashRegisterHistoryScreenState extends State<CashRegisterHistoryScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
    if (shop != null) {
      await Provider.of<CashRegisterProvider>(context, listen: false).loadTodaySession(shop.id);
      await Provider.of<BillingProvider>(context, listen: false).loadInvoices(shop.id);
      await Provider.of<ProductProvider>(context, listen: false).loadProducts(shop.id);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  List<DailyRegisterReportItem> _buildReportItems(
    BuildContext context, {
    required List<dynamic> sessions,
    required List<Invoice> allInvoices,
    required List<Product> allProducts,
  }) {
    // Map productId -> purchasePrice for accurate profit calculation
    final Map<String, double> productCosts = {
      for (final p in allProducts) p.id: p.purchasePrice,
    };

    return sessions.map<DailyRegisterReportItem>((session) {
      final sessionDate = session.date;

      // Filter invoices matching this session's date
      final sessionInvoices = allInvoices.where((inv) {
        final invDateStr = DateFormat('yyyy-MM-dd').format(inv.invoiceDate);
        return invDateStr == sessionDate;
      }).toList();

      final salesAmount = sessionInvoices.fold(0.0, (sum, inv) => sum + inv.paidAmount);

      // Profit calculation: (Selling Price - Purchase Cost) for every line item
      double totalProfit = 0.0;
      for (final inv in sessionInvoices) {
        for (final item in inv.items) {
          final costPrice = productCosts[item.productId] ?? 0.0;
          final itemProfit = item.totalAmount - (costPrice * item.quantity);
          totalProfit += itemProfit;
        }
      }

      return DailyRegisterReportItem(
        session: session,
        salesAmount: salesAmount,
        profitAmount: totalProfit,
        billCount: sessionInvoices.length,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final shop = Provider.of<ShopProvider>(context).currentShop;
    final cashProvider = Provider.of<CashRegisterProvider>(context);
    final billingProvider = Provider.of<BillingProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);

    final reportItems = _buildReportItems(
      context,
      sessions: cashProvider.sessionHistory,
      allInvoices: billingProvider.invoices,
      allProducts: productProvider.products,
    );

    final totalSales = reportItems.fold(0.0, (sum, i) => sum + i.salesAmount);
    final totalProfit = reportItems.fold(0.0, (sum, i) => sum + i.profitAmount);
    final totalBills = reportItems.fold(0, (sum, i) => sum + i.billCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Register & Profit History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print 30-Day Report',
            onPressed: reportItems.isEmpty || shop == null
                ? null
                : () {
                    RegisterReportPdfService.printRegisterReport(
                      shop: shop,
                      items: reportItems,
                    );
                  },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share PDF Report',
            onPressed: reportItems.isEmpty || shop == null
                ? null
                : () async {
                    final bytes = await RegisterReportPdfService.generateRegisterReportPdf(
                      shop: shop,
                      items: reportItems,
                    );
                    await Printing.sharePdf(
                      bytes: bytes,
                      filename: '${shop.shopName}_Register_Report_30Days.pdf',
                    );
                  },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Cards Header
                        Card(
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Last 30 Days Summary',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withAlpha(20),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${reportItems.length} Sessions Logged',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _buildStatCard('Total Sales', currencyFormat.format(totalSales), AppTheme.primary, Icons.point_of_sale),
                                    const SizedBox(width: 10),
                                    _buildStatCard('Net Profit', currencyFormat.format(totalProfit), AppTheme.success, Icons.trending_up),
                                    const SizedBox(width: 10),
                                    _buildStatCard('Total Bills', '$totalBills', Colors.purple, Icons.receipt_long),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section Title & Print Shortcut
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Daily Breakdown',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                            ),
                            if (reportItems.isNotEmpty && shop != null)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf, size: 16),
                                label: const Text('PRINT REPORT'),
                                onPressed: () {
                                  RegisterReportPdfService.printRegisterReport(
                                    shop: shop,
                                    items: reportItems,
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Daily History List
                        if (reportItems.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.history_toggle_off, size: 48, color: AppTheme.border),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No cash register sessions logged yet.',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Open cash register daily to record opening, sales, and closing balance.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reportItems.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, index) {
                              final item = reportItems[index];
                              final isPositiveProfit = item.profitAmount >= 0;

                              return Card(
                                elevation: 1,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Date & Status Header
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                                              const SizedBox(width: 6),
                                              Text(
                                                item.date,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: item.isOpen ? Colors.green.shade100 : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              item.isOpen ? 'ACTIVE SESSION' : 'CLOSED',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: item.isOpen ? Colors.green.shade800 : Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 18),

                                      // Metrics Row
                                      Row(
                                        children: [
                                          _buildDetailCol('Opening Cash', currencyFormat.format(item.openingAmount)),
                                          _buildDetailCol('Total Sales', currencyFormat.format(item.salesAmount)),
                                          _buildDetailCol('Closing Balance', currencyFormat.format(item.closingAmount), isBold: true),
                                          _buildDetailCol(
                                            'Estimated Profit',
                                            currencyFormat.format(item.profitAmount),
                                            color: isPositiveProfit ? AppTheme.success : AppTheme.danger,
                                            isBold: true,
                                          ),
                                          _buildDetailCol('Bills', '${item.billCount}'),
                                        ],
                                      ),

                                      if (item.session.notes.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Notes: ${item.session.notes}',
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                                        ),
                                      ],
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
            ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCol(String label, String value, {Color? color, bool isBold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
