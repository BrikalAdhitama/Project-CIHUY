import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cihuy/providers/app_state.dart';
import 'package:cihuy/services/google_auth_repository.dart';
import 'package:cihuy/services/profile_photo_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'google_login_test.dart' show FakeGoogle, account;

class _Repository extends GoogleAuthRepository {
  _Repository(SupabaseClient client) : super(client: client);
  String owner = 'account-a';
  @override
  String? get currentUserId => owner;
}

class _Photos extends ProfilePhotoPicker {
  _Photos(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List?> pickPhoto() async => bytes;
}

class _Cloud extends FakeGoogle {
  Completer<String>? pendingUpload;
  bool failUpload = false;
  @override
  Future<String> uploadProfilePhoto(
    String id,
    Uint8List bytes, {
    String? previousPath,
  }) async {
    if (failUpload) throw StateError('Upload ditolak');
    if (pendingUpload != null) return pendingUpload!.future;
    const path = 'a/avatar.png';
    session = GoogleAccount(
      id: id,
      profile: session!.profile.withPhoto(bytes, avatarPath: path),
      onboardingCompleted: true,
    );
    return path;
  }

  @override
  Future<void> removeProfilePhoto(String id, String previousPath) async {
    session = GoogleAccount(
      id: id,
      profile: session!.profile.withPhoto(null),
      onboardingCompleted: true,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List png;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(
      recorder,
    ).drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint());
    final picture = recorder.endRecording();
    final image = await picture.toImage(4, 4);
    png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
  });

  _Repository repository(Future<http.Response> Function(http.Request) handler) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-public-key',
      accessToken: () async => 'test-user-jwt',
      httpClient: MockClient((request) async {
        final response = await handler(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    return _Repository(client);
  }

  http.Response json(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );

  test(
    'upload precedes owner-scoped profile update; old file deleted only after commit',
    () async {
      final calls = <http.Request>[];
      final repo = repository((request) async {
        calls.add(request);
        if (request.method == 'POST') {
          return json({'Key': 'photo-profil/account-a/new.png'});
        }
        if (request.method == 'PATCH') return json({'id': 'account-a'});
        return json([]);
      });
      final path = await repo.uploadProfilePhoto(
        'account-a',
        png,
        previousPath: 'account-a/old.png',
      );
      expect(path, startsWith('account-a/'));
      expect(calls.map((r) => r.method), ['POST', 'PATCH', 'DELETE']);
      expect(calls.first.url.path, '/storage/v1/object/photo-profil/$path');
      expect(calls.first.headers['authorization'], 'Bearer test-user-jwt');
      expect(calls[1].url.queryParameters['id'], 'eq.account-a');
      expect(
        calls[1].url.queryParameters['avatar_url'],
        'eq.account-a/old.png',
      );
      expect(jsonDecode(calls[1].body)['avatar_url'], path);
      expect(jsonDecode(calls.last.body)['prefixes'], ['account-a/old.png']);
    },
  );

  test('denied upload never writes avatar_url', () async {
    final calls = <String>[];
    final repo = repository((request) async {
      calls.add(request.method);
      return json({
        'statusCode': '403',
        'error': 'Unauthorized',
        'message': 'RLS',
      }, 403);
    });
    await expectLater(
      repo.uploadProfilePhoto('account-a', png),
      throwsStateError,
    );
    expect(calls, ['POST']);
  });

  test(
    'unconfirmed profile update keeps uploaded object to avoid a dangling committed path',
    () async {
      final calls = <String>[];
      final repo = repository((request) async {
        calls.add(request.method);
        if (request.method == 'POST') return json({'Key': 'uploaded'});
        return json({'message': 'stale profile', 'code': 'PGRST116'}, 406);
      });
      await expectLater(
        repo.uploadProfilePhoto('account-a', png),
        throwsStateError,
      );
      expect(calls, ['POST', 'PATCH']);
    },
  );

  test(
    'private download validates owner and file; invalid uploads perform no network calls',
    () async {
      var calls = 0;
      final repo = repository((request) async {
        calls++;
        expect(
          request.url.path,
          contains('/photo-profil/account-a/avatar.png'),
        );
        return http.Response.bytes(
          png,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      expect(
        await repo.loadProfilePhoto('account-a', 'account-a/avatar.png'),
        png,
      );
      await expectLater(
        repo.loadProfilePhoto('account-a', 'account-b/avatar.png'),
        throwsStateError,
      );
      await expectLater(
        repo.uploadProfilePhoto('account-a', Uint8List(3)),
        throwsStateError,
      );
      await expectLater(
        repo.uploadProfilePhoto(
          'account-a',
          Uint8List(GoogleAuthRepository.maxAvatarBytes + 1),
        ),
        throwsStateError,
      );
      expect(calls, 1);
    },
  );

  test('account switch during upload prevents profile update', () async {
    final calls = <String>[];
    late _Repository repo;
    repo = repository((request) async {
      calls.add(request.method);
      repo.owner = 'account-b';
      return json({'Key': 'uploaded'});
    });
    await expectLater(
      repo.uploadProfilePhoto('account-a', png),
      throwsStateError,
    );
    expect(calls, ['POST']);
  });

  test('remove clears profile reference before deleting owned file', () async {
    final calls = <http.Request>[];
    final repo = repository((request) async {
      calls.add(request);
      return request.method == 'PATCH' ? json({'id': 'account-a'}) : json([]);
    });
    await repo.removeProfilePhoto('account-a', 'account-a/avatar.png');
    expect(calls.map((r) => r.method), ['PATCH', 'DELETE']);
    expect(jsonDecode(calls.first.body)['avatar_url'], isNull);
  });

  test(
    'cloud photo survives restoration and failed replacement preserves previous photo',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final cloud = _Cloud();
      final state = AppState(
        startSignedIn: false,
        autoTick: false,
        googleAuthRepository: cloud,
        photoPicker: _Photos(png),
      );
      addTearDown(state.dispose);
      await state.signInWithGoogle();
      await state.changeProfilePhoto();
      expect(state.profile.avatarPath, 'a/avatar.png');
      expect(state.profile.photo, png);
      cloud.failUpload = true;
      await state.changeProfilePhoto();
      expect(state.photoError, 'Upload ditolak');
      expect(state.profile.photo, png);
      final restored = AppState(
        startSignedIn: false,
        autoTick: false,
        googleAuthRepository: cloud,
      );
      addTearDown(restored.dispose);
      await restored.initializeAuth();
      expect(restored.profile.avatarPath, 'a/avatar.png');
      expect(restored.profile.photo, png);
      await restored.removeProfilePhoto();
      expect(cloud.session!.profile.avatarPath, isNull);
      expect(restored.profile.photo, isNull);
    },
  );

  test('late upload never replaces another account photo', () async {
    final cloud = _Cloud()..pendingUpload = Completer<String>();
    final state = AppState(
      startSignedIn: false,
      autoTick: false,
      googleAuthRepository: cloud,
      photoPicker: _Photos(png),
    );
    addTearDown(state.dispose);
    await state.signInWithGoogle();
    final pending = state.changeProfilePhoto();
    await Future<void>.delayed(Duration.zero);
    await state.signOut();
    cloud.next = account('b');
    await state.signInWithGoogle();
    cloud.pendingUpload!.complete('a/late.png');
    await pending;
    expect(state.profile.email, 'b@example.invalid');
    expect(state.profile.photo, isNull);
    expect(state.profile.avatarPath, isNull);
  });
}
