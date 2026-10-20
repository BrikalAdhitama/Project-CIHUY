import 'dart:async';
import 'dart:io';

import 'package:cihuy/app.dart';
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/services/mock_store.dart';
import 'package:cihuy/services/profile_photo_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _FakePhotoPicker extends ProfilePhotoPicker {
  Future<Uint8List?> Function() pick = () async => null;
  Uint8List? interruptedPhoto;

  @override
  Future<Uint8List?> pickPhoto() => pick();

  @override
  Future<void> discardLostPhoto() async {
    interruptedPhoto = null;
  }
}

void main() {
  final now = DateTime(2026, 9, 13, 10);
  final photo = File('assets/icon-app.png').readAsBytesSync();
  late _FakePhotoPicker picker;
  late AppState state;

  setUpAll(() => initializeDateFormatting('id_ID'));

  setUp(() {
    picker = _FakePhotoPicker()..pick = () async => photo;
    state = AppState(
      clock: () => now,
      store: MockStore.demo(now),
      autoTick: false,
      photoPicker: picker,
    );
  });

  tearDown(() => state.dispose());

  Future<void> mountProfile(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    state.selectTab(2);
    await tester.pumpWidget(CihuyApp(state: state));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> choosePhoto(WidgetTester tester) async {
    await tap(tester, find.byKey(const Key('edit-profile-photo')));
    await tap(tester, find.text('Pilih dari galeri'));
  }

  testWidgets('gallery photo survives profile edits and changing tabs', (
    tester,
  ) async {
    await mountProfile(tester);
    expect(find.text('BS'), findsOneWidget);

    await choosePhoto(tester);
    expect(state.profile.photo, orderedEquals(photo));
    expect(find.byKey(const Key('profile-photo')), findsOneWidget);
    expect(find.text('BS'), findsNothing);

    state.updateProfile(name: 'Sari Dewi', reason: 'Untuk hidup lebih sehat.');
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const Key('tab-home')));
    await tap(tester, find.byKey(const Key('tab-profile')));

    expect(state.profile.name, 'Sari Dewi');
    expect(state.profile.photo, orderedEquals(photo));
    expect(find.byKey(const Key('profile-photo')), findsOneWidget);
    expect(find.text('SD'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cancelling the gallery or action sheet keeps the existing photo',
    (tester) async {
      await state.changeProfilePhoto();
      await mountProfile(tester);
      picker.pick = () async => null;

      await choosePhoto(tester);
      expect(state.profile.photo, orderedEquals(photo));
      expect(state.photoError, isNull);
      expect(find.byKey(const Key('profile-photo')), findsOneWidget);

      await tap(tester, find.byKey(const Key('edit-profile-photo')));
      await tap(tester, find.text('Batal'));
      expect(state.profile.photo, orderedEquals(photo));
      expect(find.byKey(const Key('profile-photo')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a gallery failure reports the error and retains the photo', (
    tester,
  ) async {
    await state.changeProfilePhoto();
    await mountProfile(tester);
    picker.pick = () async =>
        throw PlatformException(code: 'photo_access_denied');

    await choosePhoto(tester);

    expect(state.profile.photo, orderedEquals(photo));
    expect(find.byKey(const Key('profile-photo')), findsOneWidget);
    expect(
      find.text(
        'Akses foto ditolak. Izinkan akses foto di pengaturan aplikasi lalu coba lagi.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing the photo restores the current profile initials', (
    tester,
  ) async {
    await state.changeProfilePhoto();
    state.updateProfile(name: 'Sari Dewi');
    await mountProfile(tester);

    await tap(tester, find.byKey(const Key('edit-profile-photo')));
    await tap(tester, find.text('Hapus foto'));

    expect(state.profile.photo, isNull);
    expect(find.byKey(const Key('profile-photo')), findsNothing);
    expect(find.text('SD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo actions remain reachable in landscape', (tester) async {
    await state.changeProfilePhoto();
    await mountProfile(tester, size: const Size(844, 390));

    await tap(tester, find.byKey(const Key('edit-profile-photo')));
    await tap(tester, find.text('Batal'));
    expect(state.profile.photo, orderedEquals(photo));

    await tap(tester, find.byKey(const Key('edit-profile-photo')));
    await tap(tester, find.text('Hapus foto'));
    expect(state.profile.photo, isNull);

    await choosePhoto(tester);
    expect(state.profile.photo, orderedEquals(photo));
    expect(find.byKey(const Key('profile-photo')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'new user, demo reset and account deletion clear the previous photo',
    () async {
      await state.changeProfilePhoto();
      expect(state.profile.photo, isNotNull);
      state.startNewUser(name: 'Sari');
      expect(state.profile.photo, isNull);
      expect(state.profile.name, 'Sari');

      await state.changeProfilePhoto();
      expect(state.profile.photo, isNotNull);
      state.startDemo();
      expect(state.profile.photo, isNull);

      await state.changeProfilePhoto();
      expect(state.profile.photo, isNotNull);
      state.deleteAccount();
      expect(state.profile.photo, isNull);
      expect(state.signedIn, isFalse);
    },
  );

  test('a pending gallery result cannot set a different user photo', () async {
    final oldSelection = Completer<Uint8List?>();
    picker.pick = () => oldSelection.future;
    final pendingChange = state.changeProfilePhoto();

    state.startNewUser(name: 'Sari');
    expect(state.profile.photo, isNull);

    // The previous user's platform request returns after switching accounts.
    oldSelection.complete(photo);
    await pendingChange;

    expect(state.profile.name, 'Sari');
    expect(state.profile.photo, isNull);
    expect(state.photoError, isNull);
    expect(state.pickingPhoto, isFalse);

    picker.pick = () async => photo;
    await state.changeProfilePhoto();
    expect(state.profile.photo, orderedEquals(photo));
  });

  test(
    'picker initialization discards interrupted data without changing the profile',
    () async {
      picker.interruptedPhoto = photo;
      await state.initializePhotoPicker();
      expect(picker.interruptedPhoto, isNull);
      expect(state.profile.photo, isNull);

      await state.changeProfilePhoto();
      await state.initializePhotoPicker();
      expect(state.profile.photo, orderedEquals(photo));
      expect(state.photoError, isNull);
      expect(state.pickingPhoto, isFalse);
    },
  );
}
