import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'utils/app_theme.dart';
import 'widgets/asset_icon.dart';
import 'widgets/record_forms.dart';

class CihuyApp extends StatefulWidget {
  const CihuyApp({super.key, this.state});
  final AppState? state;
  @override
  State<CihuyApp> createState() => _CihuyAppState();
}

class _CihuyAppState extends State<CihuyApp> {
  late final AppState _state = widget.state ?? AppState(startSignedIn: false);
  @override
  void initState() {
    super.initState();
    if (widget.state == null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_state.initializePhotoPicker());
    }
    if (widget.state == null) unawaited(_state.initializeAuth());
  }

  @override
  void dispose() {
    if (widget.state == null) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _state,
    child: MaterialApp(
      title: 'CIHUY',
      debugShowCheckedModeBanner: false,
      theme: cihuyTheme(),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Consumer<AppState>(
        builder: (context, state, _) => state.authLoading
            ? const _AuthLoadingScreen()
            : !state.signedIn
            ? const AuthScreen()
            : state.needsOnboarding
            ? const OnboardingScreen()
            : const AppShell(),
      ),
    ),
  );
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PopScope(
      canPop: state.tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) state.selectTab(0);
      },
      child: Scaffold(
        backgroundColor: state.tab == 2
            ? const Color(0xFF29BCBB)
            : Colors.white,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: state.tab,
            children: const [HomeScreen(), CalendarScreen(), ProfileScreen()],
          ),
        ),
        persistentFooterDecoration: const BoxDecoration(color: Colors.white),
        persistentFooterButtons: state.tab == 0
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    height: 44,
                    child: FloatingActionButton.extended(
                      key: const Key('record-now'),
                      onPressed: () => showRecordChooser(context),
                      backgroundColor: const Color(0xFF1C1C1C),
                      foregroundColor: Colors.white,
                      elevation: 3,
                      extendedPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      icon: const Icon(Icons.add, size: 19),
                      label: const Text(
                        'Catat Sekarang',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ]
            : null,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF0F1F4))),
            boxShadow: [
              BoxShadow(
                color: Color(0x07000000),
                blurRadius: 8,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              currentIndex: state.tab,
              onTap: state.selectTab,
              elevation: 0,
              backgroundColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              iconSize: 24,
              selectedItemColor: CihuyColors.teal,
              unselectedItemColor: const Color(0xFF98A2B3),
              selectedFontSize: 12,
              unselectedFontSize: 12,
              selectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined, key: Key('tab-home')),
                  activeIcon: Icon(Icons.home_rounded, key: Key('tab-home')),
                  label: 'Beranda',
                ),
                BottomNavigationBarItem(
                  icon: CihuyAssetIcon(
                    CihuyAssetIcon.calendar,
                    key: Key('tab-calendar'),
                  ),
                  label: 'Kalender',
                ),
                BottomNavigationBarItem(
                  icon: CihuyAssetIcon(
                    CihuyAssetIcon.profile,
                    key: Key('tab-profile'),
                  ),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
