import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/document_tools/document_tools_service.dart';
import '../../../services/document_tools/signature_store.dart';
import '../../../theme/app_theme.dart';
import 'doc_tool_widgets.dart';
import 'page_rendering.dart';

const _inkColors = {'Black': Color(0xFF111827), 'Blue': Color(0xFF1E3A8A)};

/// Creates a signature (or picks a saved one or a seal) and returns it as a
/// transparent PNG, or null if cancelled.
class SignatureSheet extends StatefulWidget {
  const SignatureSheet._();

  static Future<Uint8List?> show(BuildContext context) => showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const SignatureSheet._(),
  );

  @override
  State<SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<SignatureSheet> with SingleTickerProviderStateMixin {
  List<SavedSignature> _saved = const [];
  late final TabController _tabs = TabController(length: 4, vsync: this);
  bool _remember = true;
  Color _ink = _inkColors['Blue']!;

  // Draw.
  final List<List<Offset>> _strokes = [];

  // Type.
  final _name = TextEditingController();
  String _font = 'Dancing Script';

  // Photo.
  Uint8List? _photoSignature;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    SignatureStore.list().then((saved) {
      if (!mounted) return;
      setState(() => _saved = saved);
      if (saved.isNotEmpty) _tabs.index = 3;
    });
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    super.dispose();
  }

  TextStyle _typedStyle(double size) =>
      GoogleFonts.getFont(_font, fontSize: size, color: _ink);

  Future<void> _takePhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 2000);
    if (picked == null) return;
    setState(() => _working = true);
    try {
      final png = await DocumentToolsService.signatureFromPhoto(await picked.readAsBytes());
      if (mounted) setState(() => _photoSignature = png);
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  bool get _canUse => switch (_tabs.index) {
    0 => _strokes.any((s) => s.length > 1),
    1 => _name.text.trim().isNotEmpty,
    2 => _photoSignature != null,
    _ => false,
  };

  Future<void> _use() async {
    setState(() => _working = true);
    try {
      final Uint8List png;
      switch (_tabs.index) {
        case 0:
          png = await _drawnPng();
        case 1:
          await GoogleFonts.pendingFonts([_typedStyle(48)]).catchError((_) => <void>[]);
          png = await renderTextPng(_name.text.trim(), _typedStyle(48));
        default:
          png = _photoSignature!;
      }
      if (_remember) await SignatureStore.add(png);
      if (mounted) Navigator.pop(context, png);
    } catch (e) {
      if (mounted) showToolError(context, e);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// The drawn strokes, cropped to the ink, at 3× for crisp printing.
  Future<Uint8List> _drawnPng() async {
    final points = _strokes.expand((s) => s);
    var left = double.infinity, top = double.infinity, right = -double.infinity, bottom = -double.infinity;
    for (final p in points) {
      if (p.dx < left) left = p.dx;
      if (p.dx > right) right = p.dx;
      if (p.dy < top) top = p.dy;
      if (p.dy > bottom) bottom = p.dy;
    }
    const pad = 6.0, scale = 3.0;
    final width = right - left + pad * 2;
    final height = bottom - top + pad * 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(scale)
      ..translate(pad - left, pad - top);
    _SignaturePainter(_strokes, _ink).paint(canvas, Size(width, height));
    final image = await recorder.endRecording().toImage((width * scale).ceil(), (height * scale).ceil());
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
            child: Text('Your signature', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800)),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [Tab(text: 'Draw'), Tab(text: 'Type'), Tab(text: 'Photo'), Tab(text: 'Saved')],
          ),
          SizedBox(
            height: 260.h,
            child: TabBarView(
              controller: _tabs,
              physics: const NeverScrollableScrollPhysics(),
              // Builders keep each tab lazy: the typed-signature fonts are
              // downloaded only if that tab is opened.
              children: [
                Builder(builder: (_) => _buildDraw()),
                Builder(builder: (_) => _buildType()),
                Builder(builder: (_) => _buildPhoto()),
                Builder(builder: (_) => _buildSaved()),
              ],
            ),
          ),
          if (_tabs.index < 3)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Wrap(
                spacing: 8.w,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_tabs.index < 2)
                    for (final entry in _inkColors.entries)
                      ChoiceChip(
                        label: Text(entry.key),
                        selected: _ink == entry.value,
                        onSelected: (_) => setState(() => _ink = entry.value),
                      ),
                  InkWell(
                    onTap: () => setState(() => _remember = !_remember),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(value: _remember, onChanged: (v) => setState(() => _remember = v ?? true)),
                        const Text('Save for next time'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            child: _tabs.index == 3
                ? const SizedBox.shrink()
                : ToolActionButton(
                    label: 'Use this signature',
                    icon: Icons.check_rounded,
                    busy: _working,
                    onPressed: _canUse ? _use : null,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraw() {
    return Padding(
      padding: EdgeInsets.all(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 24,
              right: 24,
              bottom: 48,
              child: Container(height: 1, color: const Color(0xFFE2E8F0)),
            ),
            GestureDetector(
              onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
              child: CustomPaint(
                painter: _SignaturePainter(_strokes, _ink),
                size: Size.infinite,
              ),
            ),
            if (_strokes.isEmpty)
              const IgnorePointer(child: Center(child: Text('Sign here with your finger'))),
            Positioned(
              top: 4,
              right: 4,
              child: TextButton(
                onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
                child: const Text('Clear'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildType() {
    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name as you sign it'),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: 8.h),
        RadioGroup<String>(
          groupValue: _font,
          onChanged: (v) => setState(() => _font = v ?? _font),
          child: Column(
            children: [
              for (final font in const ['Dancing Script', 'Great Vibes', 'Allura'])
                RadioListTile<String>(
                  value: font,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _name.text.trim().isEmpty ? 'Your Name' : _name.text.trim(),
                    style: GoogleFonts.getFont(font, fontSize: 28, color: _ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoto() {
    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        Text(
          'Sign in dark ink on plain white paper, then photograph it. The paper is removed '
          'automatically. Also works for your seal.',
          style: TextStyle(fontSize: 12.sp, color: mutedText(context), height: 1.35),
        ),
        SizedBox(height: 12.h),
        if (_photoSignature != null)
          Container(
            height: 90.h,
            color: const Color(0xFFF1F5F9),
            padding: EdgeInsets.all(8.r),
            child: Image.memory(_photoSignature!, fit: BoxFit.contain),
          ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 8.w,
          children: [
            OutlinedButton.icon(
              onPressed: _working ? null : () => _takePhoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Camera'),
            ),
            OutlinedButton.icon(
              onPressed: _working ? null : () => _takePhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ],
        ),
        if (_working) Padding(padding: EdgeInsets.only(top: 12.h), child: const LinearProgressIndicator()),
      ],
    );
  }

  Widget _buildSaved() {
    if (_saved.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.r),
          child: Text(
            'Signatures you save appear here. They stay on this phone only.',
            textAlign: TextAlign.center,
            style: TextStyle(color: mutedText(context)),
          ),
        ),
      );
    }
    return GridView.count(
      padding: EdgeInsets.all(16.r),
      crossAxisCount: 2,
      mainAxisSpacing: 10.h,
      crossAxisSpacing: 10.w,
      childAspectRatio: 2,
      children: [
        for (final s in _saved)
          Stack(
            children: [
              Positioned.fill(
                child: InkWell(
                  onTap: () => Navigator.pop(context, s.png),
                  child: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Image.memory(s.png, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: 'Delete saved signature',
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.error),
                  onPressed: () async {
                    await SignatureStore.delete(s.id);
                    final saved = await SignatureStore.list();
                    if (mounted) setState(() => _saved = saved);
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  _SignaturePainter(this.strokes, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.single, 1.3, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      // Midpoint smoothing: quadratic curves through the finger's samples.
      for (var i = 1; i < stroke.length - 1; i++) {
        final mid = (stroke[i] + stroke[i + 1]) / 2;
        path.quadraticBezierTo(stroke[i].dx, stroke[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
