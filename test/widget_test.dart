import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inzeli/main.dart';

void main() {
  testWidgets('App starts and disposes its polling timers', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const InzeliApp());
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
