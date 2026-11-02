import '../models/cash_register_session.dart';

class DailyRegisterReportItem {
  final CashRegisterSession session;
  final double salesAmount;
  final double profitAmount;
  final int billCount;

  DailyRegisterReportItem({
    required this.session,
    required this.salesAmount,
    required this.profitAmount,
    required this.billCount,
  });

  double get openingAmount => session.openingAmount;
  double get closingAmount => session.closingAmount ?? (session.openingAmount + salesAmount);
  String get date => session.date;
  bool get isOpen => session.isOpen;
}
