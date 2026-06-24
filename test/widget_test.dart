import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogneva_msg_app/main.dart';

void main() {
  testWidgets('login opens chats screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OgnevaApp());

    expect(find.text('Вход в мессенджер'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('login_input')),
      'student@example.com',
    );
    await tester.enterText(find.byKey(const Key('password_input')), 'user123');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(find.text('Чаты'), findsOneWidget);
    expect(find.text('ЕГЭ Информатика 2026'), findsOneWidget);
  });

  testWidgets('chat screen opens a thread', (WidgetTester tester) async {
    await tester.pumpWidget(const OgnevaApp());
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ЕГЭ Информатика 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 ответа'));
    await tester.pumpAndSettle();

    expect(find.text('Ответы'), findsOneWidget);
    expect(find.text('Ответить в тред'), findsOneWidget);
  });
}
