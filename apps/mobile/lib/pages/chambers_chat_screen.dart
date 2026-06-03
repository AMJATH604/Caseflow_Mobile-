import 'dart:async';
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
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final _searchController = TextEditingController();
  bool _isUploading = false;
  UserProfile? _profile;
  final List<CaseComment> _optimisticNotices = [];
  CaseComment? _replyingTo;
  List<CaseComment> _currentMessagesList = [];

  // Local caching tracking
  final Map<String, bool> _localFilesExist = {};
  final Map<String, String> _localPaths = {};

  // Audio Player and Recorder
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _playingUrl;
  PlayerState _playerState = PlayerState.stopped;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordTimer;
  int _recordDuration = 0;

  // Typing indicators & Search
  RealtimeChannel? _typingChannel;
  final Set<String> _typingUsers = {};
  Timer? _typingDebounce;
  bool _amITyping = false;

  bool _isSearching = false;

  // Download tracking: attachmentUrl -> progress (0.0..1.0) or null
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initAudioPlayerListeners();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    _typingDebounce?.cancel();
    if (_typingChannel != null) {
      Supabase.instance.client.removeChannel(_typingChannel!);
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    _profile = await SupabaseService.fetchProfile();
    if (mounted) {
      setState(() {});
      _initTypingChannel();
    }
  }

  void _initTypingChannel() {
    final firmId = _firmId;
    if (firmId == null) return;

    _typingChannel = Supabase.instance.client.channel(
      'chambers_typing_$firmId',
    );

    _typingChannel!
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            final userName = payload['user_name'] as String?;
            final isTyping = payload['is_typing'] as bool? ?? false;

            if (userId == null || userId == _profile?.id) return;

            setState(() {
              if (isTyping) {
                if (userName != null) {
                  _typingUsers.add(userName);
                }
              } else {
                if (userName != null) {
                  _typingUsers.remove(userName);
                }
              }
            });
          },
        )
        .subscribe();
  }

  void _initAudioPlayerListeners() {
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _audioPosition = pos;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _audioDuration = dur;
        });
      }
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
        });
      }
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _audioPosition = Duration.zero;
          _playerState = PlayerState.stopped;
          _playingUrl = null;
        });
      }
    });
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
    final replyMessage =
        _replyingTo?.hasAttachment == true
            ? (_replyingTo!.attachmentType == 'image'
                ? '📷 Photo'
                : (_replyingTo!.attachmentType == 'video'
                    ? '🎥 Video'
                    : '📄 Document'))
            : _replyingTo?.message;
    final replySender = _replyingTo?.senderName;

    setState(() {
      _optimisticNotices.add(
        CaseComment(
          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
          firmId: _firmId!,
          senderId: _profile?.id ?? '',
          message: text,
          senderName: senderName,
          createdAt: DateTime.now(),
          replyToId: replyId,
          replyToMessage: replyMessage,
          replyToSender: replySender,
        ),
      );
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
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      if (picked == null) return;
      file = File(picked.path);
      attachmentType = 'image';
    } else if (type == 'gallery') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
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
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'txt',
          'ppt',
          'pptx',
        ],
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
      final replyMessage =
          _replyingTo?.hasAttachment == true
              ? (_replyingTo!.attachmentType == 'image'
                  ? '📷 Photo'
                  : (_replyingTo!.attachmentType == 'video'
                      ? '🎥 Video'
                      : '📄 Document'))
              : _replyingTo?.message;
      final replySender = _replyingTo?.senderName;

      setState(() {
        _replyingTo = null; // Clear reply context
      });

      await SupabaseService.postDiscussion({
        'firm_id': _firmId,
        'message':
            attachmentType == 'image'
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

  // ─── Local Caching & Custom Downloaders ───────────────
  Future<String> _getLocalFilePath(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final uri = Uri.parse(url);
    final fileName = Uri.decodeComponent(uri.pathSegments.last);
    final chambersDir = Directory('${dir.path}/caseflow_chambers');
    if (!await chambersDir.exists()) {
      await chambersDir.create(recursive: true);
    }
    return '${chambersDir.path}/$fileName';
  }

  void _checkLocalFiles(List<CaseComment> messages) async {
    for (final msg in messages) {
      if (msg.hasAttachment && msg.attachmentUrl != null) {
        final url = msg.attachmentUrl!;
        if (!_localPaths.containsKey(url)) {
          final path = await _getLocalFilePath(url);
          _localPaths[url] = path;
          final exists = await File(path).exists();
          if (mounted) {
            setState(() {
              _localFilesExist[url] = exists;
            });
          }
        }
      }
    }
  }

  Future<bool> _downloadFile(String url, String displayName) async {
    if (_downloadProgress.containsKey(url)) return false;

    try {
      setState(() => _downloadProgress[url] = 0.0);

      String relativePath = url;
      if (url.startsWith('http')) {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        final publicIdx = segments.indexOf('public');
        final authIdx = segments.indexOf('authenticated');
        final idx = publicIdx != -1 ? publicIdx : authIdx;
        if (idx != -1 && segments.length > idx + 2) {
          relativePath = segments.sublist(idx + 2).join('/');
        }
      }
      relativePath = Uri.decodeComponent(relativePath);

      debugPrint('Downloading attachment from Supabase: $relativePath');
      final bytes = await Supabase.instance.client.storage
          .from('chat-attachments')
          .download(relativePath);

      final localPath = _localPaths[url] ?? await _getLocalFilePath(url);
      _localPaths[url] = localPath;

      final file = File(localPath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        setState(() {
          _downloadProgress.remove(url);
          _localFilesExist[url] = true;
        });
      }
      return true;
    } catch (e) {
      debugPrint('Download error via Supabase: $e. Trying Dio fallback...');
      try {
        final localPath = _localPaths[url] ?? await _getLocalFilePath(url);
        _localPaths[url] = localPath;

        await Dio().download(
          url,
          localPath,
          onReceiveProgress: (received, total) {
            if (total > 0 && mounted) {
              setState(() => _downloadProgress[url] = received / total);
            }
          },
        );

        if (mounted) {
          setState(() {
            _downloadProgress.remove(url);
            _localFilesExist[url] = true;
          });
        }
        return true;
      } catch (e2) {
        debugPrint('Dio fallback download error: $e2');
        if (mounted) {
          setState(() => _downloadProgress.remove(url));
        }
        return false;
      }
    }
  }

  void _downloadInBackground(String url, String displayName) async {
    if (_downloadProgress.containsKey(url) || _localFilesExist[url] == true)
      return;

    // Prevent duplicate triggers
    _downloadProgress[url] = 0.0;

    final localPath = _localPaths[url] ?? await _getLocalFilePath(url);
    _localPaths[url] = localPath;

    try {
      String relativePath = url;
      if (url.startsWith('http')) {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        final publicIdx = segments.indexOf('public');
        final authIdx = segments.indexOf('authenticated');
        final idx = publicIdx != -1 ? publicIdx : authIdx;
        if (idx != -1 && segments.length > idx + 2) {
          relativePath = segments.sublist(idx + 2).join('/');
        }
      }
      relativePath = Uri.decodeComponent(relativePath);

      final bytes = await Supabase.instance.client.storage
          .from('chat-attachments')
          .download(relativePath);

      final file = File(localPath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        setState(() {
          _downloadProgress.remove(url);
          _localFilesExist[url] = true;
        });
      }
    } catch (e) {
      debugPrint('Background download error: $e');
      if (mounted) {
        setState(() {
          _downloadProgress.remove(url);
        });
      }
    }
  }

  // ─── Download & Open File ───────────────────────────
  Future<void> _downloadAndOpen(String url, String displayName) async {
    final localPath = _localPaths[url] ?? await _getLocalFilePath(url);
    _localPaths[url] = localPath;

    final exists = await File(localPath).exists();
    if (exists) {
      await OpenFile.open(localPath);
      return;
    }

    final success = await _downloadFile(url, displayName);
    if (success) {
      await OpenFile.open(localPath);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to download or open file")),
        );
      }
    }
  }

  // ─── Full-screen Image Viewer ──────────────────────
  void _openImageViewer(String pathOrUrl, {required bool isLocal}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => Scaffold(
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
                  child:
                      isLocal
                          ? Image.file(File(pathOrUrl), fit: BoxFit.contain)
                          : Image.network(
                            pathOrUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                ),
              ),
            ),
      ),
    );
  }

  // ─── Voice Note Recording & Playback ─────────────────
  Future<void> _playVoice(String url) async {
    if (_playingUrl == url) {
      if (_playerState == PlayerState.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
      return;
    }

    await _audioPlayer.stop();
    _playingUrl = url;

    final localPath = _localPaths[url] ?? await _getLocalFilePath(url);
    _localPaths[url] = localPath;

    if (await File(localPath).exists()) {
      await _audioPlayer.play(DeviceSource(localPath));
    } else {
      await _audioPlayer.play(UrlSource(url));
      _downloadInBackground(url, 'voice_message.m4a');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingPath = path;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          setState(() {
            _recordDuration++;
          });
        });
      }
    } catch (e) {
      debugPrint('Record start error: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (path != null && _firmId != null) {
      final file = File(path);
      if (await file.exists()) {
        setState(() => _isUploading = true);
        final url = await DiscussionRepository.uploadAttachment(
          file: file,
          firmId: _firmId!,
        );
        if (url != null) {
          final senderName = _profile?.fullName ?? "Team Member";
          await SupabaseService.postDiscussion({
            'firm_id': _firmId,
            'message': '🎤 Voice message (${_formatDuration(_recordDuration)})',
            'case_id': null,
            'sender_name': senderName,
            'attachment_url': url,
            'attachment_type': 'audio',
          });
        }
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingPath = null;
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── Save Attachment to Device ──────────────────────
  Future<void> _saveAttachmentToDevice(CaseComment msg) async {
    if (msg.attachmentUrl == null) return;
    final url = msg.attachmentUrl!;
    final fileName = msg.message
        .replaceFirst('📷 Photo', 'Image')
        .replaceFirst('🎥 Video', 'Video')
        .replaceFirst('📎 ', '');
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
                const SnackBar(
                  content: Text("Permission denied to save media to gallery."),
                ),
              );
              return;
            }
          }
        } else {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Permission denied to write to storage."),
              ),
            );
            return;
          }
        }
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName${!fileName.contains('.') ? '.$ext' : ''}';

      final localPath = _localPaths[url] ?? await _getLocalFilePath(url);
      _localPaths[url] = localPath;
      final cachedFile = File(localPath);

      if (await cachedFile.exists()) {
        await cachedFile.copy(tempPath);
      } else {
        final success = await _downloadFile(url, fileName);
        if (success && await cachedFile.exists()) {
          await cachedFile.copy(tempPath);
        } else {
          throw Exception("Download failed");
        }
      }

      if (msg.attachmentType == 'image' || msg.attachmentType == 'video') {
        final result = await ImageGallerySaverPlus.saveFile(tempPath);
        if (result != null && (result['isSuccess'] == true || result == true)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Saved successfully to Gallery! 📥"),
              ),
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
          final destPath =
              '${downloadDir.path}/$fileName${!fileName.contains('.') ? '.$ext' : ''}';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
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
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[isDark ? 700 : 300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    Icons.reply_rounded,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  title: Text(
                    "Reply",
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replyingTo = msg;
                    });
                  },
                ),
                if (!msg.hasAttachment)
                  ListTile(
                    leading: Icon(
                      Icons.copy_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    title: Text(
                      "Copy Text",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
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
                    leading: Icon(
                      Icons.download_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    title: Text(
                      "Save to Device",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _saveAttachmentToDevice(msg);
                    },
                  ),
                if (isMe && !msg.id.startsWith('temp_'))
                  ListTile(
                    leading: const Icon(
                      Icons.delete_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      "Delete for Everyone",
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (dial) => AlertDialog(
                              backgroundColor:
                                  isDark
                                      ? const Color(0xFF1F2C34)
                                      : Colors.white,
                              title: Text(
                                "Delete Message?",
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              content: Text(
                                "Are you sure you want to delete this message for everyone?",
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dial, false),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dial, true),
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
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
    final previewText =
        previewMsg.hasAttachment
            ? (previewMsg.attachmentType == 'image'
                ? '📷 Photo'
                : (previewMsg.attachmentType == 'video'
                    ? '🎥 Video'
                    : '📄 Document'))
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
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
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
            Container(width: 3, height: 36, color: const Color(0xFFD4AF37)),
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
      onTap:
          isDownloading
              ? null
              : () => _downloadAndOpen(msg.attachmentUrl!, 'Video.mp4'),
      child: Container(
        width: 260,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDark
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Share Attachment",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _attachOption(
                        Icons.camera_alt_rounded,
                        "Camera",
                        Colors.pink,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'camera');
                        },
                      ),
                      _attachOption(
                        Icons.photo_library_rounded,
                        "Gallery",
                        Colors.purple,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'gallery');
                        },
                      ),
                      _attachOption(
                        Icons.video_library_rounded,
                        "Video",
                        Colors.deepPurple,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'video');
                        },
                      ),
                      _attachOption(
                        Icons.description_rounded,
                        "Document",
                        Colors.blue,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'file');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
    );
  }

  Widget _attachOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
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
      backgroundColor:
          isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
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
                    final pendingOptimistic =
                        _optimisticNotices
                            .where(
                              (opt) =>
                                  !streamNotices.any(
                                    (s) =>
                                        s.message == opt.message &&
                                        s.senderId == opt.senderId,
                                  ),
                            )
                            .toList();
                    final allNotices = [...streamNotices, ...pendingOptimistic];
                    if (pendingOptimistic.length < _optimisticNotices.length) {
                      _optimisticNotices.removeWhere(
                        (opt) => streamNotices.any(
                          (s) =>
                              s.message == opt.message &&
                              s.senderId == opt.senderId,
                        ),
                      );
                    }

                    // Keep our tracking list updated
                    _currentMessagesList = allNotices;

                    // Asynchronously check and load local file presence
                    _checkLocalFiles(allNotices);

                    List<CaseComment> displayNotices = allNotices;
                    if (_isSearching &&
                        _searchController.text.trim().isNotEmpty) {
                      final query = _searchController.text.trim().toLowerCase();
                      displayNotices =
                          allNotices.where((msg) {
                            return msg.message.toLowerCase().contains(query);
                          }).toList();
                    }

                    if (displayNotices.isEmpty) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _isSearching
                                ? "No matching messages found"
                                : "🔒 Messages are end-to-end within your firm.\nSay hello to your team! 👋",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      );
                    }

                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                    );

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: displayNotices.length,
                      itemBuilder: (context, index) {
                        final msg = displayNotices[index];
                        final isMe = msg.senderId == _profile?.id;

                        // Date separator
                        Widget? dateSeparator;
                        if (index == 0 ||
                            !_isSameDay(
                              displayNotices[index - 1].createdAt,
                              msg.createdAt,
                            )) {
                          dateSeparator = _buildDateSeparator(
                            msg.createdAt,
                            isDark,
                          );
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
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (e, _) => Center(
                        child: Text(
                          "Error: $e",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
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
    if (_isSearching) {
      return AppBar(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : AppTheme.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Search messages...",
            hintStyle: TextStyle(color: Colors.white60),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {});
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () {
              setState(() {
                _searchController.clear();
              });
            },
          ),
        ],
      );
    }

    final subtitle =
        _typingUsers.isNotEmpty
            ? Text(
              "${_typingUsers.join(', ')} ${_typingUsers.length == 1 ? 'is' : 'are'} typing...",
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF25D366),
                fontWeight: FontWeight.bold,
              ),
            )
            : Text(
              "Tap here for firm info",
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            );

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF1F2C34) : AppTheme.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.groups_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Chambers Chat",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                subtitle,
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
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
        color:
            isDark
                ? const Color(0xFF1F2C34)
                : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3),
        ],
      ),
      child: Text(
        _formatDateLabel(date),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white60 : Colors.black45,
        ),
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

  // ─── Swipe to Reply Widget ─────────────────────────
  Widget _buildSwipeToReply({
    required Widget child,
    required CaseComment message,
  }) {
    if (message.id.startsWith('temp_')) return child;
    return Dismissible(
      key: Key('reply_${message.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        setState(() {
          _replyingTo = message;
        });
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.reply_rounded, color: Color(0xFF00A884)),
      ),
      child: child,
    );
  }

  // ─── MESSAGE BUBBLE ─────────────────────────────────
  Widget _buildBubble(CaseComment msg, bool isMe, bool isDark) {
    final bubbleColor =
        isMe
            ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
            : (isDark ? const Color(0xFF1F2C34) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF111B21);
    final metaColor = isDark ? Colors.white38 : const Color(0xFF667781);

    final bubbleWidget = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isMe),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 2),
              bottomRight: Radius.circular(isMe ? 2 : 12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _senderColor(msg.senderName ?? ''),
                      ),
                    ),
                  ),

                // ── Reply box (quoted message) ──
                if (msg.hasReply) _buildQuotedReplyBox(msg, isDark),

                // ── Attachment rendering ──
                if (msg.hasAttachment) ...[
                  if (msg.isImage)
                    _buildImageBubble(msg, isDark)
                  else if (msg.isVideo)
                    _buildVideoBubble(msg, isDark)
                  else if (msg.attachmentType == 'audio' ||
                      msg.attachmentType == 'voice')
                    _buildVoiceBubble(msg, isMe, isDark)
                  else
                    _buildDocumentBubble(msg, isMe, isDark),
                  const SizedBox(height: 4),
                ],

                // Text (hide if just an attachment label)
                if (!msg.hasAttachment)
                  Text(
                    msg.message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),

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
                        color:
                            msg.id.startsWith('temp_')
                                ? metaColor
                                : (isDark
                                    ? const Color(0xFF53BDEB)
                                    : Colors.blue),
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

    return _buildSwipeToReply(child: bubbleWidget, message: msg);
  }

  Color _senderColor(String name) {
    final colors = [
      const Color(0xFF00A884),
      const Color(0xFF53BDEB),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFFFF5722),
      const Color(0xFF009688),
      const Color(0xFF673AB7),
      const Color(0xFFE65100),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  // ─── IMAGE BUBBLE ──────────────────────────────────
  Widget _buildImageBubble(CaseComment msg, bool isDark) {
    final url = msg.attachmentUrl!;
    final localExists = _localFilesExist[url] == true;
    final localPath = _localPaths[url];

    // Background download so images cache auto
    if (!localExists && !_downloadProgress.containsKey(url)) {
      _downloadInBackground(url, 'Image.png');
    }

    return GestureDetector(
      onTap: () {
        if (localExists && localPath != null) {
          _openImageViewer(localPath, isLocal: true);
        } else {
          _openImageViewer(url, isLocal: false);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            localExists && localPath != null
                ? Image.file(
                  File(localPath),
                  width: 260,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildNetworkImage(url, isDark),
                )
                : _buildNetworkImage(url, isDark),
      ),
    );
  }

  Widget _buildNetworkImage(String url, bool isDark) {
    return Image.network(
      url,
      width: 260,
      height: 200,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          width: 260,
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value:
                  progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
              color: AppTheme.accent,
            ),
          ),
        );
      },
      errorBuilder:
          (_, __, ___) => Container(
            width: 260,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(
                Icons.broken_image_rounded,
                color: Colors.grey,
                size: 32,
              ),
            ),
          ),
    );
  }

  // ─── DOCUMENT BUBBLE ───────────────────────────────
  Widget _buildDocumentBubble(CaseComment msg, bool isMe, bool isDark) {
    final fileName = msg.message.replaceFirst('📎 ', '');
    final ext = fileName.split('.').last.toUpperCase();
    final url = msg.attachmentUrl!;
    final isDownloading = _downloadProgress.containsKey(url);
    final progress = _downloadProgress[url] ?? 0.0;
    final localExists = _localFilesExist[url] == true;

    final docColor = _docColor(ext);

    return GestureDetector(
      onTap: isDownloading ? null : () => _downloadAndOpen(url, fileName),
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: docColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child:
                    isDownloading
                        ? SizedBox(
                          width: 22,
                          height: 22,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: docColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          ext,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: docColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isDownloading
                            ? "Downloading..."
                            : (localExists ? "Tap to view" : "Tap to download"),
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Download icon
            if (!isDownloading && !localExists)
              Icon(
                Icons.download_rounded,
                size: 22,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceBubble(CaseComment msg, bool isMe, bool isDark) {
    final url = msg.attachmentUrl!;
    final isPlayingThis = _playingUrl == url;
    final isPlaying = isPlayingThis && _playerState == PlayerState.playing;

    final durationText =
        isPlayingThis && _audioDuration > Duration.zero
            ? '${_formatDuration(_audioPosition.inSeconds)} / ${_formatDuration(_audioDuration.inSeconds)}'
            : msg.message
                .replaceFirst('🎤 Voice message (', '')
                .replaceFirst(')', '');

    final progressValue =
        isPlayingThis && _audioDuration.inMilliseconds > 0
            ? _audioPosition.inMilliseconds / _audioDuration.inMilliseconds
            : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      width: 240,
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _playVoice(url),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color:
                    isMe
                        ? (isDark ? Colors.white24 : Colors.black12)
                        : (isDark ? Colors.white10 : Colors.grey[200]),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 10,
                    ),
                    activeTrackColor:
                        isDark ? Colors.white : const Color(0xFF00A884),
                    inactiveTrackColor:
                        isDark ? Colors.white24 : Colors.black12,
                    thumbColor: isDark ? Colors.white : const Color(0xFF00A884),
                  ),
                  child: Slider(
                    value: progressValue.clamp(0.0, 1.0),
                    onChanged: (val) {
                      if (isPlayingThis) {
                        final pos = Duration(
                          milliseconds:
                              (val * _audioDuration.inMilliseconds).toInt(),
                        );
                        _audioPlayer.seek(pos);
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        durationText,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      Icon(
                        Icons.mic_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF53BDEB) : Colors.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _docColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.grey;
      default:
        return AppTheme.accent;
    }
  }

  IconData _docIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.article_rounded;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  void _onTextChanged(String text) {
    if (_typingChannel == null || _profile == null) return;

    if (text.isNotEmpty && !_amITyping) {
      _amITyping = true;
      _typingChannel!.sendBroadcast(
        event: 'typing',
        payload: {
          'user_id': _profile!.id,
          'user_name': _profile!.fullName ?? 'Team Member',
          'is_typing': true,
        },
      );
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (_amITyping) {
        _amITyping = false;
        _typingChannel?.sendBroadcast(
          event: 'typing',
          payload: {
            'user_id': _profile!.id,
            'user_name': _profile!.fullName ?? 'Team Member',
            'is_typing': false,
          },
        );
      }
    });
  }

  // ─── INPUT BAR ─────────────────────────────────────
  Widget _buildInputBar(bool isDark) {
    final showMic = _msgController.text.trim().isEmpty;

    if (_isRecording) {
      return Container(
        padding: EdgeInsets.only(
          left: 6,
          right: 6,
          top: 6,
          bottom:
              MediaQuery.of(context).viewInsets.bottom > 0
                  ? 6
                  : MediaQuery.of(context).padding.bottom + 6,
        ),
        color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F2F5),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A3942) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fiber_manual_record,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordDuration),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111B21),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Recording voice...",
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 26,
              ),
              onPressed: _cancelRecording,
            ),
            const SizedBox(width: 6),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF00A884),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.send_rounded,
                  size: 22,
                  color: Colors.white,
                ),
                onPressed: _stopAndSendRecording,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 6,
        right: 6,
        top: 6,
        bottom:
            MediaQuery.of(context).viewInsets.bottom > 0
                ? 6
                : MediaQuery.of(context).padding.bottom + 6,
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
                    icon: Icon(
                      Icons.attach_file_rounded,
                      size: 22,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                    onPressed: _isUploading ? null : _showAttachmentSheet,
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF111B21),
                      ),
                      textInputAction: TextInputAction.newline,
                      onChanged: (val) {
                        _onTextChanged(val);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: "Type a message",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : Colors.grey[500],
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  // Camera shortcut
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      size: 22,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                    onPressed:
                        _isUploading
                            ? null
                            : () => _sendAttachment(type: 'camera'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send / Mic button
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFF00A884),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                showMic ? Icons.mic_rounded : Icons.send_rounded,
                size: 22,
                color: Colors.white,
              ),
              onPressed: showMic ? _startRecording : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
