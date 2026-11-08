import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/models/invoice.dart';
import '../../core/models/shop_profile.dart';
import '../../core/services/invoice_pdf_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/product_provider.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final ShopProfile shop;
  final Invoice invoice;

  const InvoicePreviewScreen({
    super.key,
    required this.shop,
    required this.invoice,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late String _currentFormat;

  @override
  void initState() {
    super.initState();
    _currentFormat = widget.shop.defaultInvoiceType;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bill #${widget.invoice.invoiceNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Invoice',
            onPressed: () async {
              final bytes = _currentFormat == 'a4'
                  ? await InvoicePdfService.generateA4Invoice(widget.shop, widget.invoice)
                  : await InvoicePdfService.generateThermalReceipt(
                      widget.shop,
                      widget.invoice,
                      is80mm: _currentFormat == 'thermal_80',
                    );
              await Printing.sharePdf(
                bytes: bytes,
                filename: '${widget.invoice.invoiceNumber}.pdf',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Direct Print',
            onPressed: () {
              InvoicePdfService.printInvoice(
                widget.shop,
                widget.invoice,
                isThermal: _currentFormat != 'a4',
                is80mm: _currentFormat == 'thermal_80',
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Horizontally scrollable layout switch bar
          Container(
            height: 56,
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.print_outlined, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  const Text('Printer Layout: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.description, size: 16),
                    label: const Text('A4 VAT Tax Invoice'),
                    selected: _currentFormat == 'a4',
                    onSelected: (val) {
                      if (val) setState(() => _currentFormat = 'a4');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.receipt, size: 16),
                    label: const Text('Thermal 58mm (POS)'),
                    selected: _currentFormat == 'thermal_58',
                    onSelected: (val) {
                      if (val) setState(() => _currentFormat = 'thermal_58');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Thermal 80mm (POS)'),
                    selected: _currentFormat == 'thermal_80',
                    onSelected: (val) {
                      if (val) setState(() => _currentFormat = 'thermal_80');
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Live PDF Preview
          Expanded(
            child: PdfPreview(
              build: (format) {
                if (_currentFormat == 'a4') {
                  return InvoicePdfService.generateA4Invoice(widget.shop, widget.invoice);
                } else {
                  return InvoicePdfService.generateThermalReceipt(
                    widget.shop,
                    widget.invoice,
                    is80mm: _currentFormat == 'thermal_80',
                  );
                }
              },
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName: '${widget.invoice.invoiceNumber}.pdf',
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('DONE / NEW BILL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                ),
                onPressed: () {
                  Provider.of<ProductProvider>(context, listen: false).loadProducts(widget.shop.id);
                  Navigator.pop(context, true);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
