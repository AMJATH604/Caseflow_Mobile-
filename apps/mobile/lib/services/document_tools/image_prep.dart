/// Prepares photos and scans for placing in a PDF: fixes phone orientation,
/// caps the resolution to what e-filing needs and re-encodes as JPEG.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'pdf_engine.dart' show DocumentToolException;

enum ScanQuality {
  /// About 200 DPI on A4: the usual e-filing minimum, smallest files.
  standard(2339, 80),

  /// About 300 DPI on A4: sharper, roughly twice the size.
  high(3508, 88);

  /// Longest side in pixels.
  final int maxSide;
  final int jpegQuality;
  const ScanQuality(this.maxSide, this.jpegQuality);
}

class ImagePrepOptions {
  final ScanQuality quality;
  final bool grayscale;
  const ImagePrepOptions({
    this.quality = ScanQuality.standard,
    this.grayscale = false,
  });
}

class ImagePrep {
  ImagePrep._();

  /// [quarterTurns] turns the image clockwise after EXIF orientation.
  static Uint8List prepare(
    Uint8List bytes,
    ImagePrepOptions options, {
    int quarterTurns = 0,
  }) {
    img.Image? image;
    try {
      image = img.decodeImage(bytes);
    } catch (_) {
      // Some decoders throw on junk input instead of returning null.
    }
    if (image == null) {
      throw const DocumentToolException(
        'One of the images could not be read. Use JPG or PNG files.',
      );
    }

    // Phones store "which way is up" in EXIF; PDF viewers ignore it.
    image = img.bakeOrientation(image);
    if (quarterTurns % 4 != 0) {
      image = img.copyRotate(image, angle: (quarterTurns % 4) * 90);
    }

    final longest = image.width > image.height ? image.width : image.height;
    if (longest > options.quality.maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: options.quality.maxSide, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: options.quality.maxSide, interpolation: img.Interpolation.average);
    }

    // JPEG has no transparency: put see-through areas on white, not black.
    if (image.hasAlpha) {
      final background = img.Image(width: image.width, height: image.height);
      img.fill(background, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(background, image);
      image = background;
    }

    if (options.grayscale) image = img.grayscale(image);

    return img.encodeJpg(image, quality: options.quality.jpegQuality);
  }
}
