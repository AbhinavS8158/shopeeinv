import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/daily_register_report_item.dart';
import '../models/shop_profile.dart';

class RegisterReportPdfService {
  static final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  static final dateFormat = DateFormat('dd/MM/yyyy');

  static Future<Uint8List> generateRegisterReportPdf({
    required ShopProfile shop,
    required List<DailyRegisterReportItem> items,
  }) async {
    final pdf = pw.Document();

    final totalOpening = items.fold(0.0, (sum, i) => sum + i.openingAmount);
    final totalClosing = items.fold(0.0, (sum, i) => sum + i.closingAmount);
    final totalSales = items.fold(0.0, (sum, i) => sum + i.salesAmount);
    final totalProfit = items.fold(0.0, (sum, i) => sum + i.profitAmount);
    final totalBills = items.fold(0, (sum, i) => sum + i.billCount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            // Shop Header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey700),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        shop.shopName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('Phone: ${shop.phone}  ${shop.gstin.isNotEmpty ? "| GSTIN: ${shop.gstin}" : ""}',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: PdfColors.blueGrey800,
                        child: pw.Text(
                          'CASH REGISTER & PROFIT REPORT',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Period: Last 30 Days', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Generated: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Summary Cards
            pw.Row(
              children: [
                _buildSummaryBox('Days Logged', '${items.length} Days'),
                pw.SizedBox(width: 8),
                _buildSummaryBox('Total Invoiced Sales', currencyFormat.format(totalSales)),
                pw.SizedBox(width: 8),
                _buildSummaryBox('Total Net Profit', currencyFormat.format(totalProfit), isHighlight: true),
                pw.SizedBox(width: 8),
                _buildSummaryBox('Bills Count', '$totalBills Bills'),
              ],
            ),
            pw.SizedBox(height: 14),

            // Table of Last 30 Days Register History
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 20,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.center,
              },
              headers: [
                'Date',
                'Status',
                'Opening (Rs.)',
                'Sales (Rs.)',
                'Closing (Rs.)',
                'Profit (Rs.)',
                'Bills',
              ],
              data: List.generate(items.length, (index) {
                final item = items[index];
                return [
                  item.date,
                  item.isOpen ? 'OPEN' : 'CLOSED',
                  item.openingAmount.toStringAsFixed(2),
                  item.salesAmount.toStringAsFixed(2),
                  item.closingAmount.toStringAsFixed(2),
                  item.profitAmount.toStringAsFixed(2),
                  '${item.billCount}',
                ];
              }),
            ),

            pw.SizedBox(height: 14),

            // Totals Row
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTALS / SUMMARY (30 DAYS):', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    'Sales: ${currencyFormat.format(totalSales)}  |  Profit: ${currencyFormat.format(totalProfit)}  |  Bills: $totalBills',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('System Generated Report - ShopeeInv',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Authorized Signatory: ________________________',
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryBox(String label, String value, {bool isHighlight = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: isHighlight ? PdfColors.green800 : PdfColors.grey400),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          color: isHighlight ? PdfColors.green50 : PdfColors.white,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: isHighlight ? PdfColors.green900 : PdfColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> printRegisterReport({
    required ShopProfile shop,
    required List<DailyRegisterReportItem> items,
  }) async {
    final bytes = await generateRegisterReportPdf(shop: shop, items: items);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${shop.shopName}_Cash_Register_Report',
    );
  }
}
