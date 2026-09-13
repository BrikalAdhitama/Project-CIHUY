import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Only the image explicitly chosen in Android's picker is read.
class ProfilePhotoPicker {
  ProfilePhotoPicker({ImagePicker? picker, ImageCropper? cropper})
    : _picker = picker ?? ImagePicker(),
      _cropper = cropper ?? ImageCropper();
  final ImagePicker _picker;
  final ImageCropper _cropper;

  Future<Uint8List?> pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    final cropped = await _cropper.cropImage(
      sourcePath: file.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan foto profil',
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
        IOSUiSettings(
          title: 'Sesuaikan foto profil',
          aspectRatioLockEnabled: true,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
      ],
    );
    return cropped == null ? null : _readPhoto(XFile(cropped.path));
  }

  /// A new mock session cannot identify the owner of an interrupted selection.
  /// Drain Android's pending result without reading or assigning its image.
  Future<void> discardLostPhoto() async {
    await _picker.retrieveLostData();
  }

  Future<Uint8List> _readPhoto(XFile file) async {
    if (await file.length() > 20 * 1024 * 1024) {
      throw const FormatException(
        'Foto terlalu besar. Pilih foto di bawah 20 MB.',
      );
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await file.readAsBytes(),
    );
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final scale = math.min(
          1.0,
          1024 / math.max(descriptor.width, descriptor.height),
        );
        final codec = await descriptor.instantiateCodec(
          targetWidth: math.max(1, (descriptor.width * scale).round()),
          targetHeight: math.max(1, (descriptor.height * scale).round()),
        );
        try {
          final frame = await codec.getNextFrame();
          try {
            final data = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (data == null) {
              throw const FormatException('Foto tidak dapat dibaca.');
            }
            return data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            );
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }
}
