import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';

class EvidenceLabScreen extends ConsumerStatefulWidget {
  final String caseId;
  const EvidenceLabScreen({super.key, required this.caseId});

  @override
  ConsumerState<EvidenceLabScreen> createState() => _EvidenceLabScreenState();
}

class _EvidenceLabScreenState extends ConsumerState<EvidenceLabScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentVoiceNote = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Evidence Lab", style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.fact_check), text: "Checklist"),
            Tab(icon: Icon(Icons.record_voice_over), text: "Witness Lab"),
            Tab(icon: Icon(Icons.photo_library), text: "Photo Vault"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChecklistTab(),
          _buildWitnessLabTab(),
          _buildPhotoVaultTab(),
        ],
      ),
    );
  }

  // ─── Checklist Tab ──────────────────────────────────
  Widget _buildChecklistTab() {
    final checklistAsync = ref.watch(evidenceChecklistProvider(widget.caseId));

    return checklistAsync.when(
      data: (items) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddItemDialog(),
              icon: const Icon(Icons.add),
              label: const Text("Add Preparation Item"),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return CheckboxListTile(
                  title: Text(item.itemName),
                  subtitle: Text(item.itemType.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  value: item.isCompleted,
                  onChanged: (val) async {
                    await SupabaseService.updateEvidenceChecklistItem(item.id, {'is_completed': val});
                    ref.invalidate(evidenceChecklistProvider(widget.caseId));
                  },
                  secondary: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      await SupabaseService.deleteEvidenceChecklistItem(item.id);
                      ref.invalidate(evidenceChecklistProvider(widget.caseId));
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text("Error: $e")),
    );
  }

  void _showAddItemDialog() {
    String name = "";
    String type = "document";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Description"),
              onChanged: (v) => name = v,
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: ["document", "witness", "exhibit", "pending"]
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
              onChanged: (v) => type = v!,
              decoration: const InputDecoration(labelText: "Type"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (name.isNotEmpty) {
                await SupabaseService.createEvidenceChecklistItem({
                  'case_id': widget.caseId,
                  'item_name': name,
                  'item_type': type,
                });
                ref.invalidate(evidenceChecklistProvider(widget.caseId));
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // ─── Witness Lab Tab ────────────────────────────────
  Widget _buildWitnessLabTab() {
    final notesAsync = ref.watch(witnessNotesProvider(widget.caseId));

    return Column(
      children: [
        _buildVoiceInputSection(),
        Expanded(
          child: notesAsync.when(
            data: (notes) => ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text("${note.witnessTag}: ${note.witnessName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(note.notes ?? "No notes"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await SupabaseService.deleteWitnessNote(note.id);
                        ref.invalidate(witnessNotesProvider(widget.caseId));
                      },
                    ),
                  ),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Error: $e")),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.primary.withValues(alpha: 0.05),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text("Examination Lab", style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : AppTheme.primary),
                onPressed: _toggleListening,
              ),
            ],
          ),
          if (_currentVoiceNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
              child: Text(_currentVoiceNote),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => setState(() => _currentVoiceNote = ""), child: const Text("Clear")),
                ElevatedButton(onPressed: _saveVoiceNote, child: const Text("Save Note")),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) {
          setState(() {
            _currentVoiceNote = val.recognizedWords;
          });
        });
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _saveVoiceNote() {
    String tag = "PW1";
    String name = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Save Note"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Witness Name"),
              onChanged: (v) => name = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Tag (e.g., PW1, DW1)"),
              onChanged: (v) => tag = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (name.isNotEmpty) {
                await SupabaseService.createWitnessNote({
                  'case_id': widget.caseId,
                  'witness_name': name,
                  'witness_tag': tag,
                  'notes': _currentVoiceNote,
                });
                ref.invalidate(witnessNotesProvider(widget.caseId));
                setState(() => _currentVoiceNote = "");
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ─── Photo Vault Tab ────────────────────────────────
  Widget _buildPhotoVaultTab() {
    final photosAsync = ref.watch(evidencePhotosProvider(widget.caseId));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _capturePhoto,
            icon: const Icon(Icons.camera_alt),
            label: const Text("Capture Evidence"),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          ),
        ),
        Expanded(
          child: photosAsync.when(
            data: (photos) => GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(photo.photoUrl, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Color(0xFF1E293B)),
                        onPressed: () async {
                          await SupabaseService.deleteEvidencePhoto(photo.id);
                          ref.invalidate(evidencePhotosProvider(widget.caseId));
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text("Error: $e")),
          ),
        ),
      ],
    );
  }

  Future<void> _capturePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      // For brevity, we simulate the upload and use a placeholder URL
      // In a real app, this would use Supabase Storage
      await SupabaseService.createEvidencePhoto({
        'case_id': widget.caseId,
        'photo_url': "https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&q=80&w=300",
        'description': "Evidence captured on ${DateTime.now()}",
      });
      ref.invalidate(evidencePhotosProvider(widget.caseId));
    }
  }
}
