import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../services/supabase_service.dart';
import '../services/repositories/discussion_repository.dart';
import '../services/providers.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

/// Full-screen WhatsApp-style chambers chat.
class ChambersChatScreen extends ConsumerStatefulWidget {
  const ChambersChatScreen({super.key});

  @override
  ConsumerState<ChambersChatScreen> createState() => _ChambersChatScreenState();
}

class _ChambersChatScreenState extends ConsumerState<ChambersChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isUploading = false;
  UserProfile? _profile;
  final List<CaseComment> _optimisticNotices = [];
  CaseComment? _replyingTo;
  List<CaseComment> _currentMessagesList = [];

  // Download tracking: attachmentUrl -> progress (0.0..1.0) or null
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    _profile = await SupabaseService.fetchProfile();
    if (mounted) setState(() {});
  }

  String? get _firmId => _profile?.firmId ?? _profile?.id;

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ─── Send Text ──────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _firmId == null) return;
    final senderName = _profile?.fullName ?? "Team Member";

    final replyId = _replyingTo?.id;
    final replyMessage = _replyingTo?.hasAttachment == true
        ? (_replyingTo!.attachmentType == 'image'
            ? '📷 Photo'
            : (_replyingTo!.attachmentType == 'video' ? '🎥 Video' : '📄 Document'))
        : _replyingTo?.message;
    final replySender = _replyingTo?.senderName;

    setState(() {
      _optimisticNotices.add(CaseComment(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        firmId: _firmId!,
        senderId: _profile?.id ?? '',
        message: text,
        senderName: senderName,
        createdAt: DateTime.now(),
        replyToId: replyId,
        replyToMessage: replyMessage,
        replyToSender: replySender,
      ));
      _replyingTo = null; // Clear reply context
    });
    _msgController.clear();
    _scrollToBottom();

    await SupabaseService.postDiscussion({
      'firm_id': _firmId,
      'message': text,
      'case_id': null,
      'sender_name': senderName,
      'reply_to_id': replyId,
      'reply_to_message': replyMessage,
      'reply_to_sender': replySender,
    });
  }

  // ─── Send Attachment ────────────────────────────────
  Future<void> _sendAttachment({required String type}) async {
    if (_firmId == null) return;

    File? file;
    String? attachmentType;

    if (type == 'camera') {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
      if (picked == null) return;
      file = File(picked.path);
      attachmentType = 'image';
    } else if (type == 'gallery') {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return;
      file = File(picked.path);
      attachmentType = 'image';
    } else if (type == 'video') {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      file = File(picked.path);
      attachmentType = 'video';
    } else if (type == 'file') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'ppt', 'pptx'],
      );
      if (result == null || result.files.isEmpty) return;
      file = File(result.files.first.path!);
      attachmentType = DiscussionRepository.getAttachmentType(file.path);
    }

    if (file == null) return;

    setState(() => _isUploading = true);

    final url = await DiscussionRepository.uploadAttachment(
      file: file,
      firmId: _firmId!,
    );

    if (url != null) {
      final senderName = _profile?.fullName ?? "Team Member";
      final fileName = file.path.split(Platform.pathSeparator).last;
      
      final replyId = _replyingTo?.id;
      final replyMessage = _replyingTo?.hasAttachment == true
          ? (_replyingTo!.attachmentType == 'image'
              ? '📷 Photo'
              : (_replyingTo!.attachmentType == 'video' ? '🎥 Video' : '📄 Document'))
          : _replyingTo?.message;
      final replySender = _replyingTo?.senderName;

      setState(() {
        _replyingTo = null; // Clear reply context
      });

      await SupabaseService.postDiscussion({
        'firm_id': _firmId,
        'message': attachmentType == 'image'
            ? '📷 Photo'
            : (attachmentType == 'video' ? '🎥 Video' : '📎 $fileName'),
        'case_id': null,
        'sender_name': senderName,
        'attachment_url': url,
        'attachment_type': attachmentType,
        'reply_to_id': replyId,
        'reply_to_message': replyMessage,
        'reply_to_sender': replySender,
      });
      _scrollToBottom();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Upload failed. Check connection.")),
        );
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  // ─── Download & Open File ───────────────────────────
  Future<void> _downloadAndOpen(String url, String displayName) async {
    try {
      setState(() => _downloadProgress[url] = 0.0);

      final dir = await getTemporaryDirectory();
      final ext = url.split('.').last.split('?').first;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$displayName';
      final filePath = '${dir.path}/$fileName${!fileName.contains('.') ? '.$ext' : ''}';

      await Dio().download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress[url] = received / total);
          }
        },
      );

      if (mounted) {
        setState(() => _downloadProgress.remove(url));
      }

      await OpenFile.open(filePath);
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(url));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open file: $e")),
        );
      }
    }
  }

  // ─── Full-screen Image Viewer ──────────────────────
  void _openImageViewer(String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              },
            ),
          ),
        ),
      ),
    ));
  }

  // ─── Save Attachment to Device ──────────────────────
  Future<void> _saveAttachmentToDevice(CaseComment msg) async {
    if (msg.attachmentUrl == null) return;
    final url = msg.attachmentUrl!;
    final fileName = msg.message.replaceFirst('📷 Photo', 'Image').replaceFirst('🎥 Video', 'Video').replaceFirst('📎 ', '');
    final ext = url.split('.').last.split('?').first.toLowerCase();

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Downloading to save to device...")),
      );

      if (Platform.isAndroid || Platform.isIOS) {
        if (msg.attachmentType == 'image' || msg.attachmentType == 'video') {
          final status = await Permission.photos.request();
          if (!status.isGranted) {
            final storageStatus = await Permission.storage.request();
            if (!storageStatus.isGranted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Permission denied to save media to gallery.")),
              );
              return;
            }
          }
        } else {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Permission denied to write to storage.")),
            );
            return;
          }
        }
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName${!fileName.contains('.') ? '.$ext' : ''}';
      
      await Dio().download(url, tempPath);

      if (msg.attachmentType == 'image' || msg.attachmentType == 'video') {
        final result = await ImageGallerySaverPlus.saveFile(tempPath);
        if (result != null && (result['isSuccess'] == true || result == true)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Saved successfully to Gallery! 📥")),
            );
          }
        } else {
          throw Exception("Gallery saving failed");
        }
      } else {
        Directory? downloadDir;
        if (Platform.isAndroid) {
          downloadDir = Directory('/storage/emulated/0/Download');
          if (!await downloadDir.exists()) {
            downloadDir = await getExternalStorageDirectory();
          }
        } else {
          downloadDir = await getApplicationDocumentsDirectory();
        }

        if (downloadDir != null) {
          final destPath = '${downloadDir.path}/$fileName${!fileName.contains('.') ? '.$ext' : ''}';
          await File(tempPath).copy(destPath);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Saved successfully to Downloads! 📂")),
            );
          }
        } else {
          throw Exception("Could not resolve downloads directory");
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e")),
        );
      }
    }
  }

  // ─── Long-press message options sheet ───────────────
  void _showMessageOptions(CaseComment msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[isDark ? 700 : 300], borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.reply_rounded, color: isDark ? Colors.white70 : Colors.black87),
              title: Text("Reply", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _replyingTo = msg;
                });
              },
            ),
            if (!msg.hasAttachment)
              ListTile(
                leading: Icon(Icons.copy_rounded, color: isDark ? Colors.white70 : Colors.black87),
                title: Text("Copy Text", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msg.message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Copied to clipboard")),
                  );
                },
              ),
            if (msg.hasAttachment)
              ListTile(
                leading: Icon(Icons.download_rounded, color: isDark ? Colors.white70 : Colors.black87),
                title: Text("Save to Device", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  Navigator.pop(ctx);
                  _saveAttachmentToDevice(msg);
                },
              ),
            if (isMe && !msg.id.startsWith('temp_'))
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                title: const Text("Delete for Everyone", style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dial) => AlertDialog(
                      backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
                      title: Text("Delete Message?", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      content: Text("Are you sure you want to delete this message for everyone?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dial, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dial, true),
                          child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await DiscussionRepository.deleteDiscussion(msg.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Message deleted")),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Delete failed: $e")),
                        );
                      }
                    }
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Reply Preview Bar above Text Input ──────────────
  Widget _buildReplyPreviewBar(bool isDark) {
    if (_replyingTo == null) return const SizedBox.shrink();

    final previewMsg = _replyingTo!;
    final previewText = previewMsg.hasAttachment
        ? (previewMsg.attachmentType == 'image'
            ? '📷 Photo'
            : (previewMsg.attachmentType == 'video' ? '🎥 Video' : '📄 Document'))
        : previewMsg.message;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5),
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3942) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFD4AF37),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      previewMsg.senderName ?? "Team Member",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      previewText,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.white54 : Colors.grey),
              onPressed: () {
                setState(() {
                  _replyingTo = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Nested Quoted Reply Block inside Bubble ──────────
  Widget _buildQuotedReplyBox(CaseComment msg, bool isDark) {
    return GestureDetector(
      onTap: () {
        if (msg.replyToId != null) {
          _scrollToMessage(msg.replyToId!);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 36,
              color: const Color(0xFFD4AF37),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.replyToSender ?? "Team Member",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    msg.replyToMessage ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Scroll to Message helper ───────────────────────
  void _scrollToMessage(String replyToId) {
    final idx = _currentMessagesList.indexWhere((m) => m.id == replyToId);
    if (idx != -1) {
      final offset = idx * 90.0;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Scrolling to original message..."),
          duration: Duration(milliseconds: 800),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Original message not found or deleted")),
      );
    }
  }

  // ─── Video Bubble Widget ─────────────────────────────
  Widget _buildVideoBubble(CaseComment msg, bool isDark) {
    final isDownloading = _downloadProgress.containsKey(msg.attachmentUrl);
    final progress = _downloadProgress[msg.attachmentUrl] ?? 0.0;
    
    return GestureDetector(
      onTap: isDownloading ? null : () => _downloadAndOpen(msg.attachmentUrl!, 'Video.mp4'),
      child: Container(
        width: 260,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
          ),
          border: Border.all(
            color: (isDark ? Colors.white10 : Colors.black12),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  Icons.video_library_rounded,
                  size: 100,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            if (isDownloading)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      color: const Color(0xFFD4AF37),
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Downloading video...",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              )
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.black45 : Colors.white70),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 40,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Tap to Play Video",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black38 : Colors.white38,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(11),
                    bottomRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.movie_creation_rounded,
                      size: 14,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "VIDEO",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : Colors.black87,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text("Share Attachment", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _attachOption(Icons.camera_alt_rounded, "Camera", Colors.pink, () {
                    Navigator.pop(ctx);
                    _sendAttachment(type: 'camera');
                  }),
                  _attachOption(Icons.photo_library_rounded, "Gallery", Colors.purple, () {
                    Navigator.pop(ctx);
                    _sendAttachment(type: 'gallery');
                  }),
                  _attachOption(Icons.video_library_rounded, "Video", Colors.deepPurple, () {
                    Navigator.pop(ctx);
                    _sendAttachment(type: 'video');
                  }),
                  _attachOption(Icons.description_rounded, "Document", Colors.blue, () {
                    Navigator.pop(ctx);
                    _sendAttachment(type: 'file');
                  }),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final firmId = _firmId;
    if (firmId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Chambers Chat")),
        body: const Center(child: Text("No firm connected")),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          // Chat wallpaper area with messages
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final noticesAsync = ref.watch(firmNoticesProvider(firmId));

                return noticesAsync.when(
                  data: (streamNotices) {
                    final pendingOptimistic = _optimisticNotices.where(
                      (opt) => !streamNotices.any((s) => s.message == opt.message && s.senderId == opt.senderId),
                    ).toList();
                    final allNotices = [...streamNotices, ...pendingOptimistic];
                    if (pendingOptimistic.length < _optimisticNotices.length) {
                      _optimisticNotices.removeWhere((opt) =>
                        streamNotices.any((s) => s.message == opt.message && s.senderId == opt.senderId),
                      );
                    }

                    // Keep our tracking list updated
                    _currentMessagesList = allNotices;

                    if (allNotices.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "🔒 Messages are end-to-end within your firm.\nSay hello to your team! 👋",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 13, height: 1.5),
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: allNotices.length,
                      itemBuilder: (context, index) {
                        final msg = allNotices[index];
                        final isMe = msg.senderId == _profile?.id;

                        // Date separator
                        Widget? dateSeparator;
                        if (index == 0 || !_isSameDay(allNotices[index - 1].createdAt, msg.createdAt)) {
                          dateSeparator = _buildDateSeparator(msg.createdAt, isDark);
                        }

                        return Column(
                          children: [
                            if (dateSeparator != null) dateSeparator,
                            _buildBubble(msg, isMe, isDark),
                          ],
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text("Error: $e", style: const TextStyle(fontSize: 12))),
                );
              },
            ),
          ),
          // Reply preview bar if active
          _buildReplyPreviewBar(isDark),
          // Input bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1F2C34) : AppTheme.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.groups_rounded, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Chambers Chat", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(
                  "Tap here for firm info",
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
          ),
      ],
    );
  }

  // ─── DATE SEPARATOR ─────────────────────────────────
  Widget _buildDateSeparator(DateTime date, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3)],
      ),
      child: Text(
        _formatDateLabel(date),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white60 : Colors.black45),
      ),
    );
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return "TODAY";
    if (diff == 1) return "YESTERDAY";
    if (diff < 7) return DateFormat('EEEE').format(date).toUpperCase();
    return DateFormat('dd MMM yyyy').format(date).toUpperCase();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ─── MESSAGE BUBBLE ─────────────────────────────────
  Widget _buildBubble(CaseComment msg, bool isMe, bool isDark) {
    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
        : (isDark ? const Color(0xFF1F2C34) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF111B21);
    final metaColor = isDark ? Colors.white38 : const Color(0xFF667781);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isMe),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 12),
            ),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender name (not me)
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      msg.senderName ?? "Team Member",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _senderColor(msg.senderName ?? '')),
                    ),
                  ),

                // ── Reply box (quoted message) ──
                if (msg.hasReply)
                  _buildQuotedReplyBox(msg, isDark),

                // ── Attachment rendering ──
                if (msg.hasAttachment) ...[
                  if (msg.isImage)
                    _buildImageBubble(msg, isDark)
                  else if (msg.isVideo)
                    _buildVideoBubble(msg, isDark)
                  else
                    _buildDocumentBubble(msg, isMe, isDark),
                  const SizedBox(height: 4),
                ],

                // Text (hide if just an attachment label)
                if (!msg.hasAttachment)
                  Text(msg.message, style: TextStyle(color: textColor, fontSize: 14, height: 1.35)),

                // Time + ticks
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(msg.createdAt.toLocal()),
                      style: TextStyle(fontSize: 10, color: metaColor),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: msg.id.startsWith('temp_')
                            ? metaColor
                            : (isDark ? const Color(0xFF53BDEB) : Colors.blue),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _senderColor(String name) {
    final colors = [
      const Color(0xFF00A884), const Color(0xFF53BDEB), const Color(0xFFE91E63),
      const Color(0xFF9C27B0), const Color(0xFFFF5722), const Color(0xFF009688),
      const Color(0xFF673AB7), const Color(0xFFE65100),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  // ─── IMAGE BUBBLE ──────────────────────────────────
  Widget _buildImageBubble(CaseComment msg, bool isDark) {
    return GestureDetector(
      onTap: () => _openImageViewer(msg.attachmentUrl!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          msg.attachmentUrl!,
          width: 260,
          height: 200,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 260, height: 200,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                  color: AppTheme.accent,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            width: 260, height: 80,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
            child: const Center(child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 32)),
          ),
        ),
      ),
    );
  }

  // ─── DOCUMENT BUBBLE ───────────────────────────────
  Widget _buildDocumentBubble(CaseComment msg, bool isMe, bool isDark) {
    final fileName = msg.message.replaceFirst('📎 ', '');
    final ext = fileName.split('.').last.toUpperCase();
    final isDownloading = _downloadProgress.containsKey(msg.attachmentUrl);
    final progress = _downloadProgress[msg.attachmentUrl] ?? 0.0;

    final docColor = _docColor(ext);

    return GestureDetector(
      onTap: isDownloading ? null : () => _downloadAndOpen(msg.attachmentUrl!, fileName),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File icon
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: docColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isDownloading
                    ? SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: progress > 0 ? progress : null,
                          color: docColor,
                        ),
                      )
                    : Icon(_docIcon(ext), size: 22, color: docColor),
              ),
            ),
            const SizedBox(width: 10),
            // File info
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111B21),
                    ),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: docColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(ext, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: docColor)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isDownloading ? "Downloading..." : "Tap to open",
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Download icon
            if (!isDownloading)
              Icon(Icons.download_rounded, size: 22, color: isDark ? Colors.white38 : Colors.black26),
          ],
        ),
      ),
    );
  }

  Color _docColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return Colors.red;
      case 'doc': case 'docx': return Colors.blue;
      case 'xls': case 'xlsx': return Colors.green;
      case 'ppt': case 'pptx': return Colors.orange;
      case 'txt': return Colors.grey;
      default: return AppTheme.accent;
    }
  }

  IconData _docIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx': return Icons.article_rounded;
      case 'xls': case 'xlsx': return Icons.table_chart_rounded;
      case 'ppt': case 'pptx': return Icons.slideshow_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  // ─── INPUT BAR ─────────────────────────────────────
  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 6, right: 6, top: 6,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 6 : MediaQuery.of(context).padding.bottom + 6,
      ),
      color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5),
      child: Row(
        children: [
          // Message field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A3942) : Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  // Attach button
                  IconButton(
                    icon: Icon(Icons.attach_file_rounded, size: 22, color: isDark ? Colors.white54 : Colors.grey[600]),
                    onPressed: _isUploading ? null : _showAttachmentSheet,
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(fontSize: 15, color: isDark ? Colors.white : const Color(0xFF111B21)),
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: "Type a message",
                        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500], fontSize: 15),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  // Camera shortcut
                  IconButton(
                    icon: Icon(Icons.camera_alt_rounded, size: 22, color: isDark ? Colors.white54 : Colors.grey[600]),
                    onPressed: _isUploading ? null : () => _sendAttachment(type: 'camera'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF00A884),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, size: 22, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
