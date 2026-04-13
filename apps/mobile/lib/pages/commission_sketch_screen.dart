
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/commission_models.dart';
import '../services/commission_service.dart';
import '../theme/app_theme.dart';

// ─── Stroke data model ──────────────────────────────────────
class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool isEraser;

  DrawingStroke({required this.points, this.color = Colors.black, this.width = 3.0, this.isEraser = false});

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    'color': color.toARGB32(),
    'width': width,
    'isEraser': isEraser,
  };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) => DrawingStroke(
    points: (json['points'] as List).map((p) => Offset(p['x'].toDouble(), p['y'].toDouble())).toList(),
    color: Color(json['color'] ?? 0xFF000000),
    width: (json['width'] ?? 3.0).toDouble(),
    isEraser: json['isEraser'] ?? false,
  );
}

// ─── Text annotation ────────────────────────────────────────
class TextAnnotation {
  Offset position;
  String text;
  double fontSize;
  Color color;

  TextAnnotation({required this.position, required this.text, this.fontSize = 14, this.color = Colors.black});

  Map<String, dynamic> toJson() => {
    'x': position.dx, 'y': position.dy, 'text': text, 'fontSize': fontSize, 'color': color.toARGB32(),
  };

  factory TextAnnotation.fromJson(Map<String, dynamic> json) => TextAnnotation(
    position: Offset((json['x'] ?? 0).toDouble(), (json['y'] ?? 0).toDouble()),
    text: json['text'] ?? '', fontSize: (json['fontSize'] ?? 14).toDouble(),
    color: Color(json['color'] ?? 0xFF000000),
  );
}

// ─── Drawing tool enum ──────────────────────────────────────
enum DrawingTool { pen, eraser, text, move }

// ─── Main Screen ────────────────────────────────────────────
class CommissionSketchScreen extends ConsumerStatefulWidget {
  final String commissionId;
  final String? visitId;
  final CommissionSketch? existingSketch;
  const CommissionSketchScreen({super.key, required this.commissionId, this.visitId, this.existingSketch});
  @override
  ConsumerState<CommissionSketchScreen> createState() => _CommissionSketchScreenState();
}

class _CommissionSketchScreenState extends ConsumerState<CommissionSketchScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  
  // Drawing state
  List<DrawingStroke> _strokes = [];
  List<DrawingStroke> _redoStack = [];
  DrawingStroke? _currentStroke;
  List<TextAnnotation> _annotations = [];
  
  // Tool state
  DrawingTool _tool = DrawingTool.pen;
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _showGrid = false;
  double _northAngle = 0.0;
  bool _showNorthArrow = true;
  
  // Sketch metadata
  String _title = 'Untitled Sketch';
  String _sketchType = 'general';
  bool _saving = false;
  
  // Color palette
  final List<Color> _colors = [
    Colors.black, const Color(0xFFEF4444), const Color(0xFF2563EB),
    const Color(0xFF10B981), const Color(0xFFF59E0B), const Color(0xFF8B5CF6),
    const Color(0xFFEC4899), const Color(0xFF6B7280),
  ];

  final List<double> _widths = [1.5, 3.0, 5.0, 8.0];

  @override
  void initState() {
    super.initState();
    if (widget.existingSketch != null) {
      _loadExistingSketch(widget.existingSketch!);
    }
  }

  void _loadExistingSketch(CommissionSketch sketch) {
    _title = sketch.title;
    _sketchType = sketch.sketchType;
    _northAngle = sketch.northAngle;
    if (sketch.sketchData != null && sketch.sketchData!['strokes'] is List) {
      _strokes = (sketch.sketchData!['strokes'] as List).map((s) => DrawingStroke.fromJson(Map<String, dynamic>.from(s))).toList();
    }
    if (sketch.annotations.isNotEmpty) {
      _annotations = sketch.annotations.map((a) => TextAnnotation.fromJson(a)).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Sketch Pad', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.grid_on), onPressed: () => setState(() => _showGrid = !_showGrid), tooltip: _showGrid ? 'Hide Grid' : 'Show Grid', color: _showGrid ? AppTheme.accent : null),
          IconButton(icon: const Icon(Icons.save_rounded), onPressed: _saving ? null : _saveSketch, tooltip: 'Save Sketch'),
        ],
      ),
      body: Column(children: [
        // Top: Sketch metadata
        _buildMetadataBar(dk),
        // Canvas area
        Expanded(child: _buildCanvas(dk)),
        // Bottom: Tool palette
        _buildToolPalette(dk),
      ]),
    );
  }

  // ─── Metadata Bar ──────────────────────────────────────
  Widget _buildMetadataBar(bool dk) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: dk ? const Color(0xFF1E1E2E) : Colors.white, border: Border(bottom: BorderSide(color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight))),
    child: Row(children: [
      // Title
      Expanded(child: GestureDetector(
        onTap: _editTitle,
        child: Row(children: [
          Icon(Icons.edit_note, size: 16, color: dk ? Colors.white38 : Colors.black38),
          const SizedBox(width: 6),
          Flexible(child: Text(_title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: dk ? Colors.white70 : const Color(0xFF1E293B)), overflow: TextOverflow.ellipsis)),
        ]),
      )),
      const SizedBox(width: 8),
      // Type selector
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: _sketchType, isDense: true,
          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent),
          items: const [
            DropdownMenuItem(value: 'general', child: Text('General')),
            DropdownMenuItem(value: 'property_layout', child: Text('Property Layout')),
            DropdownMenuItem(value: 'boundary', child: Text('Boundary')),
            DropdownMenuItem(value: 'measurement', child: Text('Measurement')),
          ],
          onChanged: (v) => setState(() => _sketchType = v ?? 'general'),
        )),
      ),
    ]),
  );

  // ─── Canvas ────────────────────────────────────────────
  Widget _buildCanvas(bool dk) {
    return RepaintBoundary(
      key: _canvasKey,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onTapUp: _tool == DrawingTool.text ? _onTapForText : null,
        child: Container(
          color: Colors.white,
          child: CustomPaint(
            painter: _SketchPainter(
              strokes: _strokes,
              currentStroke: _currentStroke,
              annotations: _annotations,
              showGrid: _showGrid,
              showNorthArrow: _showNorthArrow,
              northAngle: _northAngle,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }

  // ─── Tool Palette ─────────────────────────────────────
  Widget _buildToolPalette(bool dk) => Container(
    padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
    decoration: BoxDecoration(color: dk ? const Color(0xFF1E1E2E) : Colors.white, border: Border(top: BorderSide(color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))]),
    child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Tool buttons row
      Row(children: [
        _toolBtn(Icons.edit, 'Pen', DrawingTool.pen, dk),
        _toolBtn(Icons.auto_fix_high, 'Eraser', DrawingTool.eraser, dk),
        _toolBtn(Icons.text_fields, 'Text', DrawingTool.text, dk),
        const Spacer(),
        // Undo/Redo
        IconButton(icon: Icon(Icons.undo, color: _strokes.isEmpty ? (dk ? Colors.white12 : Colors.black12) : (dk ? Colors.white54 : Colors.black54)), onPressed: _strokes.isEmpty ? null : _undo, iconSize: 20),
        IconButton(icon: Icon(Icons.redo, color: _redoStack.isEmpty ? (dk ? Colors.white12 : Colors.black12) : (dk ? Colors.white54 : Colors.black54)), onPressed: _redoStack.isEmpty ? null : _redo, iconSize: 20),
        IconButton(icon: Icon(Icons.delete_outline, color: AppTheme.error.withValues(alpha: 0.6)), onPressed: _clearAll, iconSize: 20),
        // North arrow toggle
        IconButton(
          icon: Icon(Icons.navigation, color: _showNorthArrow ? AppTheme.accent : (dk ? Colors.white24 : Colors.black26)),
          onPressed: () => setState(() => _showNorthArrow = !_showNorthArrow),
          iconSize: 20,
          tooltip: 'North Arrow',
        ),
      ]),
      const SizedBox(height: 6),
      // Color palette + stroke width
      Row(children: [
        // Colors
        ..._colors.map((c) => GestureDetector(
          onTap: () => setState(() { _selectedColor = c; _tool = DrawingTool.pen; }),
          child: Container(
            width: 28, height: 28, margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: c, shape: BoxShape.circle,
              border: Border.all(color: _selectedColor == c && _tool == DrawingTool.pen ? AppTheme.accent : Colors.transparent, width: 2.5),
              boxShadow: _selectedColor == c && _tool == DrawingTool.pen ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 6)] : null,
            ),
          ),
        )),
        const Spacer(),
        // Stroke widths
        ..._widths.map((w) => GestureDetector(
          onTap: () => setState(() => _strokeWidth = w),
          child: Container(
            width: 28, height: 28, margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _strokeWidth == w ? AppTheme.accent : (dk ? Colors.white24 : Colors.black12)),
            ),
            child: Center(child: Container(width: w + 2, height: w + 2, decoration: BoxDecoration(color: _strokeWidth == w ? AppTheme.accent : (dk ? Colors.white38 : Colors.black26), shape: BoxShape.circle))),
          ),
        )),
      ]),
    ])),
  );

  Widget _toolBtn(IconData icon, String label, DrawingTool tool, bool dk) {
    final active = _tool == tool;
    return GestureDetector(
      onTap: () => setState(() => _tool = tool),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppTheme.accent : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: active ? AppTheme.accent : (dk ? Colors.white38 : Colors.black38)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: active ? AppTheme.accent : (dk ? Colors.white38 : Colors.black38))),
        ]),
      ),
    );
  }

  // ─── Drawing Handlers ─────────────────────────────────
  void _onPanStart(DragStartDetails d) {
    if (_tool == DrawingTool.text || _tool == DrawingTool.move) return;
    setState(() {
      _currentStroke = DrawingStroke(
        points: [d.localPosition],
        color: _tool == DrawingTool.eraser ? Colors.white : _selectedColor,
        width: _tool == DrawingTool.eraser ? _strokeWidth * 3 : _strokeWidth,
        isEraser: _tool == DrawingTool.eraser,
      );
      _redoStack.clear();
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke = DrawingStroke(
        points: [..._currentStroke!.points, d.localPosition],
        color: _currentStroke!.color,
        width: _currentStroke!.width,
        isEraser: _currentStroke!.isEraser,
      );
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_currentStroke == null) return;
    setState(() {
      _strokes.add(_currentStroke!);
      _currentStroke = null;
    });
  }

  void _onTapForText(TapUpDetails d) {
    _showTextAnnotationDialog(d.localPosition);
  }

  // ─── Actions ──────────────────────────────────────────
  void _undo() { setState(() { _redoStack.add(_strokes.removeLast()); }); }
  void _redo() { setState(() { _strokes.add(_redoStack.removeLast()); }); }
  void _clearAll() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Clear Sketch?'),
      content: const Text('This will remove all strokes and annotations.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () { Navigator.pop(ctx); setState(() { _strokes.clear(); _redoStack.clear(); _annotations.clear(); }); },
          child: const Text('Clear', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _editTitle() {
    final ctrl = TextEditingController(text: _title);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Sketch Title'),
      content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Enter sketch title')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () { setState(() => _title = ctrl.text.isNotEmpty ? ctrl.text : 'Untitled Sketch'); Navigator.pop(ctx); }, child: const Text('Save')),
      ],
    ));
  }

  void _showTextAnnotationDialog(Offset position) {
    final ctrl = TextEditingController();
    final dk = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: dk ? const Color(0xFF1E1E2E) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Add Text Label', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: dk ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(height: 16),
            TextField(controller: ctrl, autofocus: true, style: GoogleFonts.inter(fontSize: 14), decoration: InputDecoration(hintText: 'e.g., "Room A — 12ft x 10ft"', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
              onPressed: () {
                if (ctrl.text.isNotEmpty) {
                  setState(() => _annotations.add(TextAnnotation(position: position, text: ctrl.text, color: _selectedColor)));
                }
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Add Label', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white)),
            )),
          ]),
        ),
      ),
    );
  }

  // ─── Save & Export ────────────────────────────────────
  Future<void> _saveSketch() async {
    setState(() => _saving = true);
    try {
      // Prepare stroke data as JSON
      final sketchData = {
        'strokes': _strokes.map((s) => s.toJson()).toList(),
      };
      final annotationsJson = _annotations.map((a) => a.toJson()).toList();

      // Export canvas as PNG
      Uint8List? imageBytes;
      try {
        final boundary = _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          imageBytes = byteData?.buffer.asUint8List();
        }
      } catch (e) {
        debugPrint('Canvas export error: $e');
      }

      if (widget.existingSketch != null) {
        // Update existing sketch
        String? imageUrl = widget.existingSketch!.sketchImageUrl;
        if (imageBytes != null) {
          imageUrl = await CommissionService.uploadSketchImage(
            commissionId: widget.commissionId, sketchId: widget.existingSketch!.id, imageBytes: imageBytes,
          );
        }
        await CommissionService.updateSketch(widget.existingSketch!.id, {
          'title': _title, 'sketch_type': _sketchType, 'sketch_data': sketchData,
          'annotations': annotationsJson, 'north_angle': _northAngle,
          'sketch_image_url': imageUrl,
        });
      } else {
        // Create new sketch
        final sketch = await CommissionService.createSketch({
          'commission_id': widget.commissionId,
          'visit_id': widget.visitId,
          'title': _title, 'sketch_type': _sketchType, 'sketch_data': sketchData,
          'annotations': annotationsJson, 'north_angle': _northAngle,
        });
        if (imageBytes != null) {
          final imageUrl = await CommissionService.uploadSketchImage(
            commissionId: widget.commissionId, sketchId: sketch.id, imageBytes: imageBytes,
          );
          await CommissionService.updateSketch(sketch.id, {'sketch_image_url': imageUrl});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✅ Sketch saved!'), backgroundColor: AppTheme.success));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Custom Painter ─────────────────────────────────────────
class _SketchPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final List<TextAnnotation> annotations;
  final bool showGrid;
  final bool showNorthArrow;
  final double northAngle;

  _SketchPainter({required this.strokes, this.currentStroke, required this.annotations, this.showGrid = false, this.showNorthArrow = true, this.northAngle = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw grid
    if (showGrid) {
      final gridPaint = Paint()..color = const Color(0xFFE5E7EB)..strokeWidth = 0.5;
      for (double x = 0; x < size.width; x += 30) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // Draw strokes
    for (final stroke in [...strokes, if (currentStroke != null) currentStroke!]) {
      if (stroke.points.length < 2) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = BlendMode.srcOver;

      final path = Path()..moveTo(stroke.points[0].dx, stroke.points[0].dy);
      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw text annotations
    for (final ann in annotations) {
      final textSpan = TextSpan(text: ann.text, style: TextStyle(color: ann.color, fontSize: ann.fontSize, fontWeight: FontWeight.w600));
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      // Background
      final bgRect = Rect.fromLTWH(ann.position.dx - 3, ann.position.dy - 2, textPainter.width + 6, textPainter.height + 4);
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)), Paint()..color = Colors.white.withValues(alpha: 0.85));
      textPainter.paint(canvas, ann.position);
    }

    // Draw north arrow
    if (showNorthArrow) {
      _drawNorthArrow(canvas, Offset(size.width - 40, 40));
    }
  }

  void _drawNorthArrow(Canvas canvas, Offset center) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(northAngle * 3.14159 / 180);

    // Arrow body
    final arrowPaint = Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, -18)  // tip
      ..lineTo(-7, 8)
      ..lineTo(0, 3)
      ..lineTo(7, 8)
      ..close();
    canvas.drawPath(path, arrowPaint);

    // South half
    final southPaint = Paint()..color = const Color(0xFF94A3B8)..style = PaintingStyle.fill;
    final southPath = Path()
      ..moveTo(0, 18)
      ..lineTo(-7, -3)
      ..lineTo(0, 3)
      ..lineTo(7, -3)
      ..close();
    canvas.drawPath(southPath, southPaint);

    // N label
    final textSpan = TextSpan(text: 'N', style: TextStyle(color: const Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w900));
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -32));

    // Circle
    canvas.drawCircle(Offset.zero, 22, Paint()..color = const Color(0xFF94A3B8)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SketchPainter old) => true;
}
