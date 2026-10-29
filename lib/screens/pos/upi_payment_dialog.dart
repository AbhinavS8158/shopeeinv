import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/shop_profile.dart';
import '../../core/theme/app_theme.dart';

class UpiPaymentDialog extends StatelessWidget {
  final ShopProfile shop;
  final double amount;
  final String billNumber;
  final VoidCallback onPaymentConfirmed;

  const UpiPaymentDialog({
    super.key,
    required this.shop,
    required this.amount,
    required this.billNumber,
    required this.onPaymentConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
    final upiUrl = 'upi://pay?pa=${shop.upiId}&pn=${Uri.encodeComponent(shop.shopName)}&am=${amount.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent('Bill $billNumber')}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'UPI QR Payment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              currency.format(amount),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask customer to scan with any UPI App (GPay, PhonePe, Paytm)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: QrImageView(
                data: upiUrl,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'UPI ID: ${shop.upiId}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('CONFIRM PAYMENT RECEIVED'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  onPaymentConfirmed();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
