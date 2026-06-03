import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/commission_service.dart';
import '../theme/app_theme.dart';

class CommissionWitnessScreen extends ConsumerStatefulWidget {
  final String commissionId;
  final String visitId;
  const CommissionWitnessScreen({
    super.key,
    required this.commissionId,
    required this.visitId,
  });
  @override
  ConsumerState<CommissionWitnessScreen> createState() =>
      _CommissionWitnessScreenState();
}

class _CommissionWitnessScreenState
    extends ConsumerState<CommissionWitnessScreen> {
  final _nameCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _statementCtrl = TextEditingController();
  String _idType = 'aadhaar';
  Uint8List? _photoBytes;
  bool _saving = false;

  // Speech to text
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;

  // Audio Recording (missing in previous version)
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;

  // Signature
  final GlobalKey _signatureKey = GlobalKey();
  final List<List<Offset>> _signatureStrokes = [];
  List<Offset>? _currentSignatureStroke;

  final _idTypes = [
    'aadhaar',
    'voter_id',
    'pan',
    'driving_license',
    'passport',
    'other',
  ];
  final _idLabels = {
    'aadhaar': 'Aadhaar',
    'voter_id': 'Voter ID',
    'pan': 'PAN',
    'driving_license': 'Driving License',
    'passport': 'Passport',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening')
          setState(() => _isListening = false);
      },
    );
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idNumberCtrl.dispose();
    _statementCtrl.dispose();
    _speech.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Record Witness',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Witness Photo
          _sectionHeader(dk, Icons.camera_alt, 'Witness Photo', AppTheme.info),
          const SizedBox(height: 8),
          _buildPhotoCapture(dk),
          const SizedBox(height: 20),

          // Section 2: Witness Details
          _sectionHeader(dk, Icons.person, 'Witness Details', AppTheme.accent),
          const SizedBox(height: 8),
          _buildDetailsCard(dk),
          const SizedBox(height: 20),

          // Section 3: Statement (Text/Dictation)
          _sectionHeader(
            dk,
            Icons.description,
            'Statement (Text)',
            AppTheme.accentViolet,
          ),
          const SizedBox(height: 8),
          _buildStatementCard(dk),
          const SizedBox(height: 20),

          // Section 4: Audio Statement (NEW)
          _sectionHeader(
            dk,
            Icons.mic,
            'Audio Statement (Original Voice)',
            AppTheme.error,
          ),
          const SizedBox(height: 8),
          _buildAudioRecorder(dk),
          const SizedBox(height: 20),

          // Section 5: Signature
          _sectionHeader(dk, Icons.draw, 'Digital Signature', AppTheme.warning),
          const SizedBox(height: 8),
          _buildSignaturePad(dk),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveWitness,
              icon: const Icon(Icons.save_rounded),
              label: Text(
                'Save Witness Record',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(bool dk, IconData icon, String title, Color color) =>
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: dk ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      );

  // ─── Photo Capture ────────────────────────────────────
  Widget _buildPhotoCapture(bool dk) => Container(
    decoration: BoxDecoration(
      color: dk ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
      ),
    ),
    child:
        _photoBytes != null
            ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.memory(
                    _photoBytes!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => setState(() => _photoBytes = null),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            )
            : InkWell(
              onTap: _capturePhoto,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.add_a_photo,
                      size: 40,
                      color: dk ? Colors.white24 : Colors.black26,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to capture witness photo',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: dk ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Photo will be GPS-tagged',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: dk ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  ],
                ),
              ),
            ),
  );

  // ─── Details Card ─────────────────────────────────────
  Widget _buildDetailsCard(bool dk) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dk ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
      ),
    ),
    child: Column(
      children: [
        TextField(
          controller: _nameCtrl,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: dk ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            labelText: 'Full Name *',
            hintText: 'Enter witness full name',
            prefixIcon: const Icon(Icons.person_outline, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _idType,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: dk ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            labelText: 'ID Type',
            prefixIcon: const Icon(Icons.badge_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
          ),
          items:
              _idTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(_idLabels[t] ?? t),
                    ),
                  )
                  .toList(),
          onChanged: (v) => setState(() => _idType = v ?? 'aadhaar'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _idNumberCtrl,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: dk ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            labelText: 'ID Number',
            hintText: 'Enter ID number',
            prefixIcon: const Icon(Icons.numbers, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
          ),
        ),
      ],
    ),
  );

  // ─── Statement Card ───────────────────────────────────
  Widget _buildStatementCard(bool dk) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dk ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
      ),
    ),
    child: Column(
      children: [
        TextField(
          controller: _statementCtrl,
          maxLines: 8,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.6,
            color: dk ? Colors.white : const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            hintText:
                'Record witness statement...\n\nTap the mic button to dictate.',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accent),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Voice dictation button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _speechAvailable ? _toggleListening : null,
            icon: Icon(_isListening ? Icons.stop : Icons.mic, size: 20),
            label: Text(
              _isListening ? 'Stop Dictation' : 'Dictate Statement',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isListening ? AppTheme.error : AppTheme.accentViolet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_isListening)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.error.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Listening... Speak clearly',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  // ─── Audio Statement Recorder (NEW) ───────────────────
  Widget _buildAudioRecorder(bool dk) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dk ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _audioPath != null
                    ? 'Audio Recorded'
                    : (_isRecording
                        ? 'Recording...'
                        : 'Record Audio Statement'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dk ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _audioPath != null
                    ? 'Original voice statement captured'
                    : (_isRecording
                        ? 'Recording in progress'
                        : 'Tap to record original voice'),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: dk ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
        if (_audioPath != null && !_isRecording)
          IconButton(
            onPressed: () => setState(() => _audioPath = null),
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _toggleRecording,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  _isRecording
                      ? AppTheme.error
                      : (_audioPath != null
                          ? AppTheme.success
                          : AppTheme.error.withValues(alpha: 0.1)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isRecording
                  ? Icons.stop
                  : (_audioPath != null ? Icons.play_arrow : Icons.mic),
              color:
                  _isRecording || _audioPath != null
                      ? Colors.white
                      : AppTheme.error,
              size: 24,
            ),
          ),
        ),
      ],
    ),
  );

  // ─── Signature Pad ────────────────────────────────────
  Widget _buildSignaturePad(bool dk) => Container(
    decoration: BoxDecoration(
      color: dk ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
      ),
    ),
    child: Column(
      children: [
        RepaintBoundary(
          key: _signatureKey,
          child: GestureDetector(
            onPanStart:
                (d) =>
                    setState(() => _currentSignatureStroke = [d.localPosition]),
            onPanUpdate: (d) {
              if (_currentSignatureStroke != null)
                setState(() => _currentSignatureStroke!.add(d.localPosition));
            },
            onPanEnd: (_) {
              if (_currentSignatureStroke != null)
                setState(() {
                  _signatureStrokes.add(List.from(_currentSignatureStroke!));
                  _currentSignatureStroke = null;
                });
            },
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
              ),
              child: CustomPaint(
                painter: _SignaturePainter(
                  strokes: _signatureStrokes,
                  current: _currentSignatureStroke,
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: dk ? const Color(0xFF2D2D3F) : AppTheme.borderLight,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Sign above with finger',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: dk ? Colors.white38 : Colors.black38,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed:
                    () => setState(() {
                      _signatureStrokes.clear();
                      _currentSignatureStroke = null;
                    }),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ─── Actions ──────────────────────────────────────────
  Future<void> _capturePhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  void _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = p.join(
          dir.path,
          'witness_audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        await _recorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _audioPath = null;
        });
      }
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() {
            final existing = _statementCtrl.text;
            if (existing.isNotEmpty &&
                !existing.endsWith(' ') &&
                !existing.endsWith('\n')) {
              _statementCtrl.text = '$existing ${result.recognizedWords}';
            } else {
              _statementCtrl.text = '$existing${result.recognizedWords}';
            }
            _statementCtrl.selection = TextSelection.fromPosition(
              TextPosition(offset: _statementCtrl.text.length),
            );
          });
        },
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 10),
        localeId: 'en_IN',
      );
    }
  }

  Future<void> _saveWitness() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter witness name')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Create witness record
      final witness = await CommissionService.createWitness({
        'commission_id': widget.commissionId,
        'visit_id': widget.visitId,
        'witness_name': _nameCtrl.text.trim(),
        'id_type': _idType,
        'id_number':
            _idNumberCtrl.text.isNotEmpty ? _idNumberCtrl.text.trim() : null,
        'statement_text':
            _statementCtrl.text.isNotEmpty ? _statementCtrl.text.trim() : null,
      });

      // Upload photo
      if (_photoBytes != null) {
        final photoUrl = await CommissionService.uploadWitnessFile(
          commissionId: widget.commissionId,
          witnessId: witness.id,
          fileBytes: _photoBytes!,
          fileName: 'photo.jpg',
          folder: 'photos',
        );
        await CommissionService.updateWitness(witness.id, {
          'photo_url': photoUrl,
        });
      }

      // Upload audio (NEW)
      if (_audioPath != null) {
        final audioFile = File(_audioPath!);
        if (await audioFile.exists()) {
          final audioUrl = await CommissionService.uploadWitnessFile(
            commissionId: widget.commissionId,
            witnessId: witness.id,
            fileBytes: await audioFile.readAsBytes(),
            fileName: 'statement.m4a',
            folder: 'audio',
          );
          await CommissionService.updateWitness(witness.id, {
            'audio_url': audioUrl,
          });
        }
      }

      // Upload signature
      if (_signatureStrokes.isNotEmpty) {
        try {
          final boundary =
              _signatureKey.currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
          if (boundary != null) {
            final image = await boundary.toImage(pixelRatio: 2.0);
            final byteData = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (byteData != null) {
              final sigUrl = await CommissionService.uploadWitnessFile(
                commissionId: widget.commissionId,
                witnessId: witness.id,
                fileBytes: byteData.buffer.asUint8List(),
                fileName: 'signature.png',
                folder: 'signatures',
              );
              await CommissionService.updateWitness(witness.id, {
                'signature_url': sigUrl,
              });
            }
          }
        } catch (e) {
          debugPrint('Signature upload error: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Witness "${_nameCtrl.text}" recorded!'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Signature Painter ──────────────────────────────────────
class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset>? current;
  _SignaturePainter({required this.strokes, this.current});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = const Color(0xFF1E293B)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
    for (final stroke in [...strokes, if (current != null) current!]) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
    // Baseline
    final linePaint =
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..strokeWidth = 1;
    canvas.drawLine(
      Offset(20, size.height - 30),
      Offset(size.width - 20, size.height - 30),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter old) => true;
}
