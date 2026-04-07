import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_todo_ai/app/app.dart';
import 'package:my_todo_ai/core/config/database_initializer.dart';

void main() {
  testWidgets('App shell renders', (WidgetTester tester) async {
    await ensureDatabaseInitialized();
    await tester.pumpWidget(const ProviderScope(child: TodoAiApp()));

    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
