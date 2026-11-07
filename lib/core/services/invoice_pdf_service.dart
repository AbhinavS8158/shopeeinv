import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice.dart';
import '../models/shop_profile.dart';

class InvoicePdfService {
  static final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);
  static final dateFormat = DateFormat('dd/MM/yyyy hh:mm a');

  /// Generate A4 VAT Tax Invoice
  static Future<Uint8List> generateA4Invoice(ShopProfile shop, Invoice invoice) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey700),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            shop.shopName.toUpperCase(),
                            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(shop.address, style: const pw.TextStyle(fontSize: 9)),
                          if (shop.city.isNotEmpty || shop.state.isNotEmpty)
                            pw.Text('${shop.city}, ${shop.state} - ${shop.pincode}', style: const pw.TextStyle(fontSize: 9)),
                          pw.SizedBox(height: 2),
                          if (shop.gstin.isNotEmpty)
                            pw.Text('VAT / TRN: ${shop.gstin}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Phone: ${shop.phone}  ${shop.email.isNotEmpty ? " | Email: ${shop.email}" : ""}',
                              style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: PdfColors.blueGrey800,
                            child: pw.Text(
                              'VAT TAX INVOICE',
                              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text('Invoice No: ${invoice.invoiceNumber}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Date: ${dateFormat.format(invoice.invoiceDate)}', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Payment Mode: ${invoice.paymentMode.toUpperCase()}', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Status: ${invoice.paymentStatus.toUpperCase()}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: invoice.paymentStatus == 'paid' ? PdfColors.green800 : PdfColors.red800,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Billed To / Customer Details
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILLED TO (BUYER DETAILS):', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.SizedBox(height: 2),
                    pw.Text('Name: ${invoice.customerName}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    if (invoice.customerPhone.isNotEmpty)
                      pw.Text('Phone: ${invoice.customerPhone}', style: const pw.TextStyle(fontSize: 9)),
                    if (invoice.customerGstin.isNotEmpty)
                      pw.Text('VAT / TRN: ${invoice.customerGstin}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              // Table of items
              pw.Expanded(
                child: pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
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
                    6: pw.Alignment.centerRight,
                    7: pw.Alignment.centerRight,
                  },
                  headers: ['#', 'Item Description', 'Qty', 'Rate', 'Disc', 'VAT %', 'VAT Amt', 'Total (Rs.)'],
                  data: List.generate(invoice.items.length, (index) {
                    final item = invoice.items[index];
                    return [
                      '${index + 1}',
                      item.productName,
                      '${item.quantity} ${item.unit}',
                      item.unitPrice.toStringAsFixed(2),
                      item.discountAmount > 0 ? item.discountAmount.toStringAsFixed(2) : '-',
                      '${item.gstRate.toStringAsFixed(0)}%',
                      item.taxAmount.toStringAsFixed(2),
                      item.totalAmount.toStringAsFixed(2),
                    ];
                  }),
                ),
              ),

              pw.SizedBox(height: 10),

              // Summary & Totals
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left side: Bank / UPI QR Info & Terms
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (shop.upiId.isNotEmpty) ...[
                          pw.Row(
                            children: [
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: 'upi://pay?pa=${shop.upiId}&pn=${Uri.encodeComponent(shop.shopName)}&am=${invoice.grandTotal.toStringAsFixed(2)}&cu=INR',
                                width: 60,
                                height: 60,
                              ),
                              pw.SizedBox(width: 8),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Scan UPI QR to Pay:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                  pw.Text(shop.upiId, style: const pw.TextStyle(fontSize: 8)),
                                  pw.Text('Amount: ${currencyFormat.format(invoice.grandTotal)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                        ],
                        pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text(shop.termsAndConditions, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),

                  // Right side: Tax Breakdown & Grand Total
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Column(
                        children: [
                          _buildSummaryRow('Subtotal:', currencyFormat.format(invoice.subtotal)),
                          if (invoice.discountAmount > 0)
                            _buildSummaryRow('Discount:', '- ${currencyFormat.format(invoice.discountAmount)}', color: PdfColors.red800),
                          _buildSummaryRow('Taxable Value:', currencyFormat.format(invoice.taxableAmount)),
                          if (invoice.totalTax > 0)
                            _buildSummaryRow('VAT Amount:', currencyFormat.format(invoice.totalTax)),
                          if (invoice.roundOff != 0)
                            _buildSummaryRow('Round Off:', invoice.roundOff.toStringAsFixed(2)),
                          pw.Divider(thickness: 1),
                          _buildSummaryRow(
                            'Grand Total:',
                            currencyFormat.format(invoice.grandTotal),
                            isBold: true,
                            fontSize: 11,
                          ),
                          pw.Divider(thickness: 1),
                          _buildSummaryRow('Paid Amount:', currencyFormat.format(invoice.paidAmount)),
                          if (invoice.dueAmount > 0)
                            _buildSummaryRow('Balance Due:', currencyFormat.format(invoice.dueAmount), color: PdfColors.red800, isBold: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),
              // Footer Signatory
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Computer Generated Invoice', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.SizedBox(height: 25),
                      pw.Text('For ${shop.shopName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Thermal POS Receipt (58mm or 80mm roll)
  static Future<Uint8List> generateThermalReceipt(ShopProfile shop, Invoice invoice, {bool is80mm = false}) async {
    final pdf = pw.Document();
    final double width = is80mm ? 72 * PdfPageFormat.mm : 56 * PdfPageFormat.mm;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(shop.shopName.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              if (shop.address.isNotEmpty)
                pw.Text(shop.address, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
              if (shop.phone.isNotEmpty)
                pw.Text('Ph: ${shop.phone}', style: const pw.TextStyle(fontSize: 7)),
              if (shop.gstin.isNotEmpty)
                pw.Text('VAT / TRN: ${shop.gstin}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Divider(thickness: 0.5),

              // Bill Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Bill: ${invoice.invoiceNumber}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yy HH:mm').format(invoice.invoiceDate), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              if (invoice.customerName.isNotEmpty && invoice.customerName != 'Walk-in Customer')
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text('Cust: ${invoice.customerName} (${invoice.customerPhone})', style: const pw.TextStyle(fontSize: 7)),
                ),
              pw.Divider(thickness: 0.5),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('Item', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Items List
              ...invoice.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          item.productName,
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                          style: const pw.TextStyle(fontSize: 6.5),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('${item.quantity.toStringAsFixed(item.quantity % 1 == 0 ? 0 : 1)} ${item.unit}',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 6.5)),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          item.unitPrice.toStringAsFixed(2),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 6.5),
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          item.totalAmount.toStringAsFixed(2),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 6.5),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 0.5),

              // Totals
              _buildThermalRow('Subtotal:', invoice.subtotal.toStringAsFixed(2)),
              if (invoice.discountAmount > 0)
                _buildThermalRow('Discount:', '-${invoice.discountAmount.toStringAsFixed(2)}'),
              if (invoice.totalTax > 0)
                _buildThermalRow('Tax (VAT):', invoice.totalTax.toStringAsFixed(2)),
              if (invoice.roundOff != 0)
                _buildThermalRow('Round Off:', invoice.roundOff.toStringAsFixed(2)),
              pw.Divider(thickness: 1),
              _buildThermalRow('TOTAL:', 'Rs. ${invoice.grandTotal.toStringAsFixed(2)}', isBold: true, fontSize: 9),
              pw.Divider(thickness: 1),
              _buildThermalRow('Payment Mode:', invoice.paymentMode.toUpperCase()),
              _buildThermalRow('Paid Amount:', 'Rs. ${invoice.paidAmount.toStringAsFixed(2)}'),
              if (invoice.dueAmount > 0)
                _buildThermalRow('Due Amount:', 'Rs. ${invoice.dueAmount.toStringAsFixed(2)}', isBold: true),

              pw.SizedBox(height: 6),

              // QR Code for UPI payment (if applicable)
              if (shop.upiId.isNotEmpty) ...[
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'upi://pay?pa=${shop.upiId}&pn=${Uri.encodeComponent(shop.shopName)}&am=${invoice.grandTotal.toStringAsFixed(2)}&cu=INR',
                  width: 50,
                  height: 50,
                ),
                pw.SizedBox(height: 2),
                pw.Text('Scan to Pay via UPI', style: const pw.TextStyle(fontSize: 6)),
                pw.SizedBox(height: 4),
              ],

              pw.Text('*** THANK YOU VISIT AGAIN ***', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 9, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  static pw.Widget _buildThermalRow(String label, String value, {bool isBold = false, double fontSize = 7}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  /// Print or share invoice
  static Future<void> printInvoice(ShopProfile shop, Invoice invoice, {bool isThermal = false, bool is80mm = false}) async {
    final bytes = isThermal
        ? await generateThermalReceipt(shop, invoice, is80mm: is80mm)
        : await generateA4Invoice(shop, invoice);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: '${shop.shopName}_${invoice.invoiceNumber}',
    );
  }
}
