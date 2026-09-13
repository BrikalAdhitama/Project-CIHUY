import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cihuy/services/profile_photo_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class StubImagePicker extends ImagePicker {
  XFile? result;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => result;
}

class StubImageCropper extends ImageCropper {
  bool cancelled = false;
  @override
  Future<CroppedFile?> cropImage({
    required String sourcePath,
    int? maxWidth,
    int? maxHeight,
    CropAspectRatio? aspectRatio,
    ImageCompressFormat compressFormat = ImageCompressFormat.jpg,
    int compressQuality = 90,
    List<PlatformUiSettings>? uiSettings,
  }) async => cancelled ? null : CroppedFile(sourcePath);
}

Future<XFile> imageFixture(Uint8List bytes) async {
  final directory = await Directory.systemTemp.createTemp('cihuy-photo-test-');
  final file = File('${directory.path}/photo.png');
  await file.writeAsBytes(bytes);
  addTearDown(() async {
    await file.delete();
    await directory.delete();
  });
  return XFile(file.path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'gallery service decodes and bounds a wide photo without distortion',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 2048, 1024),
        ui.Paint()..color = const ui.Color(0xFF2FC6C2),
      );
      final picture = recorder.endRecording();
      final input = await picture.toImage(2048, 1024);
      final bytes = (await input.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      input.dispose();
      picture.dispose();
      final picker = StubImagePicker()..result = await imageFixture(bytes);
      final result = await ProfilePhotoPicker(
        picker: picker,
        cropper: StubImageCropper(),
      ).pickPhoto();
      expect(result, isNotNull);
      final codec = await ui.instantiateImageCodec(result!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 1024);
      expect(frame.image.height, 512);
      frame.image.dispose();
      codec.dispose();
    },
  );

  test(
    'gallery service returns null on cancel and rejects corrupt images',
    () async {
      final picker = StubImagePicker();
      final service = ProfilePhotoPicker(
        picker: picker,
        cropper: StubImageCropper(),
      );
      expect(await service.pickPhoto(), isNull);
      picker.result = await imageFixture(Uint8List.fromList([0, 1, 2, 3]));
      await expectLater(service.pickPhoto(), throwsA(isA<Exception>()));
    },
  );

  test('cancelling crop returns no replacement photo', () async {
    final picker = StubImagePicker()..result = XFile('assets/icon-app.png');
    final cropper = StubImageCropper()..cancelled = true;
    final service = ProfilePhotoPicker(picker: picker, cropper: cropper);
    expect(await service.pickPhoto(), isNull);
  });
}
