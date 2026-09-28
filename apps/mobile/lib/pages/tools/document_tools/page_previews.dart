import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';

/// Renders small page images of one PDF in the background, in page order,
/// notifying listeners as each one arrives.
class PdfPreviewLoader extends ChangeNotifier {
  final List<ImageProvider?> images;
  StreamSubscription<PdfRaster>? _subscription;
  bool failed = false;

  PdfPreviewLoader(Uint8List pdf, int pageCount, {double dpi = 30})
    : images = List.filled(pageCount, null) {
    var next = 0;
    try {
      _subscription = Printing.raster(pdf, dpi: dpi).listen(
        (raster) {
          if (next < images.length) images[next++] = PdfRasterImage(raster);
          notifyListeners();
        },
        onError: (_) {
          failed = true;
          notifyListeners();
        },
      );
    } catch (_) {
      failed = true;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// A page image with its number; [quarterTurns] shows a pending rotation.
class PageThumb extends StatelessWidget {
  final ImageProvider? image;
  final int pageNumber;
  final int quarterTurns;
  final double width;
  const PageThumb({
    super.key,
    required this.image,
    required this.pageNumber,
    this.quarterTurns = 0,
    this.width = 64,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = Container(
      width: width,
      height: width * 1.41,
      alignment: Alignment.center,
      color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
      child: Text('$pageNumber', style: TextStyle(fontSize: 14.sp, color: Colors.black38)),
    );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
        color: Colors.white,
      ),
      child: image == null
          ? placeholder
          : AnimatedRotation(
              turns: quarterTurns / 4,
              duration: const Duration(milliseconds: 200),
              child: SizedBox(
                width: width,
                height: width * 1.41,
                child: Image(image: image!, fit: BoxFit.contain, gaplessPlayback: true),
              ),
            ),
    );
  }
}
