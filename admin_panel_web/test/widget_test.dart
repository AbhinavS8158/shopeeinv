import 'package:flutter_test/flutter_test.dart';
import 'package:admin_panel_web/main.dart';

void main() {
  testWidgets('ShopeeInvAdminApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ShopeeInvAdminApp());
    expect(find.byType(ShopeeInvAdminApp), findsOneWidget);
  });
}
