import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/supabase_service.dart';
import '../../services/repositories/discussion_repository.dart';
import '../../services/providers.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class BroadcastNode extends ConsumerStatefulWidget {
  const BroadcastNode({super.key});

  @override
  ConsumerState<BroadcastNode> createState() => _BroadcastNodeState();
}

class _BroadcastNodeState extends ConsumerState<BroadcastNode> {
  final _noticeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<CaseComment> _optimisticNotices = [];
  final List<String> _deletedIds = [];
  UserProfile? _profile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _noticeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.fetchProfile();
    if (mounted) setState(() => _profile = profile);
  }

  Future<void> _sendAttachment({required String type, required String firmId}) async {
    File? file;
    String attachmentType = 'file';

    if (type == 'camera' || type == 'gallery') {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: type == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked == null) return;
      file = File(picked.path);
      attachmentType = 'image';
    } else if (type == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;
      file = File(result.files.first.path!);
      attachmentType = DiscussionRepository.getAttachmentType(file.path);
    }

    if (file == null) return;

    setState(() => _isUploading = true);

    final url = await DiscussionRepository.uploadAttachment(
      file: file,
      firmId: firmId,
    );

    if (url != null) {
      final senderName = _profile?.fullName ?? "Team Member";
      await SupabaseService.postDiscussion({
        'firm_id': firmId,
        'message': attachmentType == 'image' ? '📷 Photo' : '📎 ${file.path.split('/').last}',
        'case_id': null,
        'sender_name': senderName,
        'attachment_url': url,
        'attachment_type': attachmentType,
      });
      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to upload. Check your internet connection.")),
        );
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  void _showAttachmentSheet(String firmId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Share", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachOption(Icons.camera_alt_rounded, "Camera", Colors.pink, () {
                    Navigator.pop(ctx);
                    _sendAttachment(type: 'camera', firmId: firmId);
                  }),
                  _buildAttachOption(Icons.photo_library_rounded, "Gallery", Colors.purple, () {
                    Navigator.pop(ctx);
                    _sendAttachment(type: 'gallery', firmId: firmId);
                  }),
                  _buildAttachOption(Icons.insert_drive_file_rounded, "Document", Colors.blue, () {
                    Navigator.pop(ctx);
                    _sendAttachment(type: 'file', firmId: firmId);
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) return const Center(child: CircularProgressIndicator());
    return _buildNoticeBoard();
  }

  Widget _buildNoticeBoard() {
    final firmId = _profile?.firmId ?? _profile?.id;
    if (firmId == null) return const Center(child: Text("No firm connection"));
    final noticesAsync = ref.watch(firmNoticesProvider(firmId));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey),
      ),
      child: Column(
        children: [
          Expanded(
            child: noticesAsync.when(
              data: (streamNotices) {
                if (streamNotices.isNotEmpty) {
                  SupabaseService.updateOffset(streamNotices.last.createdAt);
                }

                final pendingOptimistic = _optimisticNotices.where(
                  (opt) => !streamNotices.any((s) => s.message == opt.message && s.senderId == opt.senderId),
                ).toList();

                final allNotices = [...streamNotices, ...pendingOptimistic]
                    .where((n) => !_deletedIds.contains(n.id))
                    .toList();
                
                allNotices.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                if (allNotices.isEmpty) {
                  return const Center(child: Text("No broadcasts found.", style: TextStyle(color: Colors.grey, fontSize: 12)));
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: false,
                  padding: const EdgeInsets.all(16),
                  itemCount: allNotices.length,
                  itemBuilder: (context, index) {
                    final msg = allNotices[index];
                    final isMe = msg.senderId == _profile?.id;
                    return _buildNoticeBubble(msg, isMe);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Connection error: $e")),
            ),
          ),
          _buildInputArea(firmId),
        ],
      ),
    );
  }

  Widget _buildNoticeBubble(CaseComment msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (isMe) {
            _showDeleteDialog(msg);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.accent : (isDark ? const Color(0xFFE2E8F0) : Colors.black.withOpacity(0.03)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Text(msg.senderName ?? "Team Member", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.accent.withOpacity(0.8))),
              
              // Attachment rendering
              if (msg.hasAttachment) ...[
                if (msg.isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      msg.attachmentUrl!,
                      width: 220,
                      height: 160,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 220, height: 160,
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        width: 220, height: 60,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey)),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isMe ? Colors.black : Colors.white).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.insert_drive_file_rounded, size: 20, color: isMe ? Colors.black87 : AppTheme.accent),
                        const SizedBox(width: 8),
                        Flexible(child: Text(msg.message, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isMe ? Colors.black87 : const Color(0xFF334155)))),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
              ],
              
              if (!msg.hasAttachment)
                Text(msg.message, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black), fontSize: 13, fontWeight: isMe ? FontWeight.w600 : FontWeight.w400)),
              
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(msg.createdAt.toIST()), 
                    style: TextStyle(fontSize: 8, color: (isMe ? Colors.white : (isDark ? Colors.white : Colors.black)).withOpacity(0.4))
                  ),
                  if (msg.id.startsWith('temp'))
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.access_time_rounded, size: 8, color: isMe ? Colors.white70 : Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(CaseComment msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete message?"),
        content: const Text("This message will be removed for everyone in the team."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (msg.id.startsWith('temp')) {
                 setState(() => _optimisticNotices.removeWhere((m) => m.id == msg.id));
                 return;
              }
              setState(() => _deletedIds.add(msg.id));
              final messenger = ScaffoldMessenger.of(context);
              try {
                await SupabaseService.deleteDiscussion(msg.id);
              } catch (e) {
                if (mounted) {
                   setState(() => _deletedIds.remove(msg.id));
                   messenger.showSnackBar(SnackBar(content: Text("Delete failed: $e")));
                }
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(String firmId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.02),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, size: 24, color: AppTheme.accent),
            onPressed: _isUploading ? null : () => _showAttachmentSheet(firmId),
          ),
          Expanded(
            child: TextField(
              controller: _noticeController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: _isUploading ? "Uploading..." : "Broadcast to firm...", 
                border: InputBorder.none, 
                filled: false
              ),
            ),
          ),
          IconButton(
            icon: _isUploading 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                : const Icon(Icons.send_rounded, color: AppTheme.accent),
            onPressed: _isUploading ? null : () async {
              final text = _noticeController.text.trim();
              if (text.isEmpty) return;
              final senderName = _profile?.fullName ?? "Team Member";
              
              final optimisticMsg = CaseComment(
                id: 'temp_${DateTime.now().millisecondsSinceEpoch}', 
                firmId: firmId, 
                senderId: _profile?.id ?? '', 
                message: text, 
                senderName: senderName, 
                createdAt: SupabaseService.syncedNow
              );
              
              setState(() => _optimisticNotices.add(optimisticMsg));
              _noticeController.clear();

              try {
                await SupabaseService.postDiscussion({
                  'firm_id': firmId, 
                  'message': text, 
                  'case_id': null, 
                  'sender_name': senderName
                });
              } catch (e) {
                setState(() => _optimisticNotices.removeWhere((m) => m.id == optimisticMsg.id));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send: $e")));
              }
            },
          ),
        ],
      ),
    );
  }
}
