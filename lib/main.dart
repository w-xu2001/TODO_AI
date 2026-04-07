import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/database_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureDatabaseInitialized();
  runApp(const ProviderScope(child: TodoAiApp()));
}
