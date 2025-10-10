import 'package:flutter_test/flutter_test.dart';
import 'package:inzeli/main.dart'; // adjust package name if different

void main() {
  testWidgets('smoke test', (tester) async {
    await tester.pumpWidget(const InzeliApp());
  });
}
