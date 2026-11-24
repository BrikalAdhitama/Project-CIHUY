import 'package:cihuy/services/profile_photo_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

class _Gallery extends ImagePicker {
  final calls = <String>[];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls.add('gallery');
    expect(source, ImageSource.gallery);
    expect(requestFullMetadata, isFalse);
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Kanal lama yang meminta izin galeri luas. Memilih satu foto tetap bisa
  // dilakukan tanpa kanal ini karena pemilih foto sistem hanya menyerahkan
  // berkas yang dipilih pengguna.
  const legacyChannel = MethodChannel('cihuy/photo_permission');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late _Gallery gallery;
  late ProfilePhotoPicker picker;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    gallery = _Gallery();
    picker = ProfilePhotoPicker(picker: gallery);
    messenger.setMockMethodCallHandler(legacyChannel, (call) async {
      fail('Izin galeri tidak boleh diminta lagi (${call.method}).');
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(legacyChannel, null);
  });

  test('memilih foto tanpa meminta izin galeri dan pembatalan aman', () async {
    expect(gallery.calls, isEmpty);
    expect(await picker.pickPhoto(), isNull);
    expect(gallery.calls, ['gallery']);
  });
}
