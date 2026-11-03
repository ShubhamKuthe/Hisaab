import 'package:flutter/material.dart';

import 'app.dart';
import 'data/store.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(JsonFileStore());
  await state.init();
  runApp(HisaabApp(state: state));
}
