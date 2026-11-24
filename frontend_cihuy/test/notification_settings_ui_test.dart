import 'package:cihuy/models/notification_settings.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/providers/notification_controller.dart';
import 'package:cihuy/screens/notification_settings_screen.dart';
import 'package:cihuy/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _TestNotificationController extends NotificationController {
  _TestNotificationController(super.app);

  void update(NotificationSettings value) {
    settings = value;
    notifyListeners();
  }
}

void main() {
  testWidgets('pengaturan turunan terkunci saat notifikasi utama mati', (
    tester,
  ) async {
    final app = AppState(autoTick: false);
    final controller = _TestNotificationController(app);
    addTearDown(() {
      controller.dispose();
      app.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: app),
          ChangeNotifierProvider<NotificationController>.value(
            value: controller,
          ),
        ],
        child: MaterialApp(
          theme: cihuyTheme(),
          home: const NotificationSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(2));
    expect(switches.first.value, isFalse);
    expect(switches.last.onChanged, isNull);
    expect(find.text('Zona waktu perangkat'), findsOneWidget);

    controller.update(const NotificationSettings(enabled: true));
    await tester.pumpAndSettle();

    switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.first.onChanged, isNotNull);
    expect(switches.last.onChanged, isNotNull);
  });
}
