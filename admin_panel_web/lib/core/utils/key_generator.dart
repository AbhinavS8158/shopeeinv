import 'dart:math';

class KeyGenerator {
  static const String _chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// Generates a formatted license key, e.g. POS-ABCD-1234-EFGH
  static String generateLicenseKey({String prefix = 'POS'}) {
    final random = Random.secure();
    final segments = <String>[];

    for (int s = 0; s < 3; s++) {
      String seg = '';
      for (int i = 0; i < 4; i++) {
        seg += _chars[random.nextInt(_chars.length)];
      }
      segments.pushOrAdd(seg);
    }

    return '$prefix-${segments.join('-')}';
  }

  /// Calculate expiry date from duration type
  static DateTime? calculateExpiryDate(String validityType, {DateTime? fromDate, DateTime? customDate}) {
    if (validityType == 'lifetime') return null;
    if (validityType == 'custom') return customDate;

    final base = fromDate ?? DateTime.now();

    switch (validityType) {
      case '30_days':
        return base.add(const Duration(days: 30));
      case '3_months':
        return DateTime(base.year, base.month + 3, base.day);
      case '6_months':
        return DateTime(base.year, base.month + 6, base.day);
      case '1_year':
      default:
        return DateTime(base.year + 1, base.month, base.day);
    }
  }
}

extension _ListPush on List<String> {
  void pushOrAdd(String val) => add(val);
}
