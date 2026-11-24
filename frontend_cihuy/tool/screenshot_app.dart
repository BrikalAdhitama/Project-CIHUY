// Entrypoint sementara untuk mengambil screenshot Play Store.
// Tidak dipakai oleh build produksi (`lib/main.dart` tetap yang dirilis).
import 'package:cihuy/app.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  final state = AppState(autoTick: false)..startDemo();
  runApp(CihuyApp(state: state));
}
