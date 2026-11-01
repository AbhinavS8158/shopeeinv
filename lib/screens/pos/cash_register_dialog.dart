import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/shop_profile.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/billing_provider.dart';
import '../../providers/cash_register_provider.dart';
import '../../providers/shop_provider.dart';

class CashRegisterDialog extends StatefulWidget {
  final VoidCallback? onSessionStarted;

  const CashRegisterDialog({super.key, this.onSessionStarted});

  static Future<void> showIfRequired(BuildContext context) async {
    final shop = Provider.of<ShopProvider>(context, listen: false).currentShop;
    if (shop == null) return;

    final cashProvider = Provider.of<CashRegisterProvider>(context, listen: false);
    await cashProvider.loadTodaySession(shop.id);

    if (!cashProvider.hasOpenSession && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const CashRegisterDialog(),
      );
    }
  }

  @override
  State<CashRegisterDialog> createState() => _CashRegisterDialogState();
}

class _CashRegisterDialogState extends State<CashRegisterDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cashProvider = Provider.of<CashRegisterProvider>(context);
    final billingProvider = Provider.of<BillingProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final currentShop = shopProvider.currentShop;
    final session = cashProvider.currentSession;
    final isOpen = cashProvider.hasOpenSession;

    // Calculation for closing
    final opening = session?.openingAmount ?? 0.0;
    final openedAt = session?.openedAt ?? DateTime.now();
    final totalSalesSince = billingProvider.getSalesSince(openedAt);
    final cashSalesSince = billingProvider.getCashSalesSince(openedAt);
    final upiSalesSince = billingProvider.getUpiSalesSince(openedAt);
    final autoClosingAmount = opening + totalSalesSince;
    final autoCashInDrawer = opening + cashSalesSince;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? AppTheme.warning.withAlpha(30)
                          : AppTheme.success.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOpen ? Icons.lock_clock : Icons.point_of_sale,
                      color: isOpen ? AppTheme.warning : AppTheme.success,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOpen ? 'Daily Cash Register Closing' : 'Daily Cash Register Opening',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          DateFormat('EEEE, dd MMM yyyy').format(DateTime.now()),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (isOpen)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 18),

              if (!isOpen) ...[
                // OPENING REGISTRATION MODE
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryLight.withAlpha(60)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enter your counter starting float/cash (Opening Amount) to start today\'s POS billing session.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  decoration: const InputDecoration(
                    labelText: 'Opening Amount (Rs.) *',
                    hintText: 'e.g. 500 or 1000',
                    prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'e.g. Petty cash / 100x5 notes',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle),
                    label: const Text('OPEN REGISTER & START BILLING', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            final val = double.tryParse(_amountController.text.trim()) ?? 0.0;
                            if (currentShop == null) return;
                            setState(() => _isSaving = true);
                            final ok = await cashProvider.openSession(
                              shopId: currentShop.id,
                              openingAmount: val,
                              notes: _notesController.text.trim(),
                            );
                            setState(() => _isSaving = false);
                            if (ok && mounted) {
                              Navigator.pop(context);
                              widget.onSessionStarted?.call();
                            }
                          },
                  ),
                ),
              ] else ...[
                // CLOSING CALCULATION MODE
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Opening Amount:', currencyFormat.format(opening), isBold: true),
                      const SizedBox(height: 6),
                      _buildSummaryRow('Cash Sales Collected:', '+ ${currencyFormat.format(cashSalesSince)}', color: AppTheme.success),
                      const SizedBox(height: 6),
                      _buildSummaryRow('UPI / Digital Sales:', '+ ${currencyFormat.format(upiSalesSince)}', color: AppTheme.primaryLight),
                      const Divider(height: 16),
                      _buildSummaryRow('Total Invoiced Sales:', currencyFormat.format(totalSalesSince), isBold: true),
                      const Divider(height: 16),
                      _buildSummaryRow(
                        'Total Closing Amount (Opening + Bills):',
                        currencyFormat.format(autoClosingAmount),
                        isBold: true,
                        fontSize: 16,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(height: 4),
                      _buildSummaryRow(
                        'Physical Cash in Drawer (Opening + Cash):',
                        currencyFormat.format(autoCashInDrawer),
                        fontSize: 13,
                        color: Colors.green.shade800,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Closing Remarks / Audit Notes (Optional)',
                    hintText: 'e.g. Register verified and balanced',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CONTINUE BILLING'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.lock),
                        label: const Text('CLOSE REGISTER', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Close Cash Register?'),
                                    content: Text(
                                      'Are you sure you want to end today\'s register session with Closing Balance of ${currencyFormat.format(autoClosingAmount)}?',
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Yes, Close'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true && mounted && currentShop != null) {
                                  setState(() => _isSaving = true);
                                  final ok = await cashProvider.closeSession(
                                    shopId: currentShop.id,
                                    closingAmount: autoClosingAmount,
                                    notes: _notesController.text.trim(),
                                  );
                                  setState(() => _isSaving = false);
                                  if (ok && mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Cash register closed with ${currencyFormat.format(autoClosingAmount)}'),
                                        backgroundColor: AppTheme.success,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: AppTheme.textPrimary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? (isBold ? AppTheme.primaryDark : AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
