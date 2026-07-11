import 'package:flutter_test/flutter_test.dart';
import 'package:it_park_mobile_app/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ITParkApp());
  });
}
