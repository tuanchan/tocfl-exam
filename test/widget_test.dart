import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttertocflexam/core/app_theme.dart';

void main() {
  testWidgets('nút ứng dụng chỉ hiển thị chữ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AppTextButton(label: 'Bắt đầu', onPressed: () {}),
        ),
      ),
    );

    expect(find.text('Bắt đầu'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });
}
