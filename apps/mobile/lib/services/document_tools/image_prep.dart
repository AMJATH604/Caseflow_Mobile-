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

  /// Raw RGBA pixels (as rendered from a PDF page) to a JPEG.
  static Uint8List rgbaToJpeg((Uint8List, int, int, int) input) {
    final (rgba, width, height, quality) = input;
    final image = img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
    );
    // Pages can render with a transparent background; JPEG would make it black.
    final page = img.Image(width: width, height: height);
    img.fill(page, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(page, image);
    return img.encodeJpg(page, quality: quality);
  }

  /// A signature or seal photographed on paper, as a PNG with the paper
  /// made transparent and cropped to the ink. Ink keeps its colour; its
  /// edges fade smoothly instead of looking cut out.
  static Uint8List signatureFromPhoto(Uint8List bytes) {
    img.Image? photo;
    try {
      photo = img.decodeImage(bytes);
    } catch (_) {
      // Handled below.
    }
    if (photo == null) {
      throw const DocumentToolException('The photo could not be read. Use a JPG or PNG.');
    }
    photo = img.bakeOrientation(photo);
    if (photo.width > 1200 || photo.height > 1200) {
      photo = photo.width >= photo.height
          ? img.copyResize(photo, width: 1200)
          : img.copyResize(photo, height: 1200);
    }

    // Paper is the bright majority: anything clearly darker than it is ink.
    final lums = [for (final p in photo) img.getLuminanceRgb(p.r, p.g, p.b).toInt()]..sort();
    final paper = lums[(lums.length * 0.6).floor()];
    final inkBelow = (paper * 0.78).round();
    final clearAbove = (paper * 0.92).round();

    final out = img.Image(width: photo.width, height: photo.height, numChannels: 4);
    var left = photo.width, top = photo.height, right = -1, bottom = -1;
    for (final p in photo) {
      final lum = img.getLuminanceRgb(p.r, p.g, p.b).toInt();
      if (lum >= clearAbove) continue;
      final alpha = lum <= inkBelow
          ? 255
          : (255 * (clearAbove - lum) / (clearAbove - inkBelow)).round();
      out.setPixelRgba(p.x, p.y, p.r, p.g, p.b, alpha);
      if (p.x < left) left = p.x;
      if (p.x > right) right = p.x;
      if (p.y < top) top = p.y;
      if (p.y > bottom) bottom = p.y;
    }
    if (right < 0) {
      throw const DocumentToolException(
        'No signature found in the photo. Sign in dark ink on white paper and try again.',
      );
    }
    const pad = 6;
    final x = (left - pad).clamp(0, out.width - 1);
    final y = (top - pad).clamp(0, out.height - 1);
    final cropped = img.copyCrop(
      out,
      x: x,
      y: y,
      width: (right + pad).clamp(0, out.width - 1) - x + 1,
      height: (bottom + pad).clamp(0, out.height - 1) - y + 1,
    );
    return img.encodePng(cropped);
  }
}
