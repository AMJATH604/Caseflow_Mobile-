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
import '../components/profile_avatar.dart';

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
    final senderName = _profile?.fullName ?? 'Team Member';

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

    final url = await SupabaseService.uploadChambersAttachment(
      file: file,
      firmId: _firmId!,
    );

    if (url != null && attachmentType != null) {
      final senderName = _profile?.fullName ?? 'Team Member';
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
        _replyingTo = null;
      });

      await SupabaseService.postChambersAttachment(
        firmId: _firmId!,
        message: attachmentType == 'image'
            ? '📷 Photo'
            : (attachmentType == 'video' ? '🎥 Video' : '📄 Document'),
        url: url,
        type: attachmentType,
        senderName: senderName,
        replyToId: replyId,
        replyToMessage: replyMessage,
        replyToSender: replySender,
      );
      _scrollToBottom();
    }

    if (mounted) setState(() => _isUploading = false);
  }

  // ─── Local cache / file helpers ──────────────────────
  Future<String> _getLocalFilePath(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = url.split('/').last.split('?').first;
    return '${dir.path}/$name';
  }

  void _checkLocalFiles(List<CaseComment> messages) async {
    for (final m in messages) {
      if (m.attachmentUrl != null) {
        final url = m.attachmentUrl!;
        if (!_localFilesExist.containsKey(url)) {
          final path = await _getLocalFilePath(url);
          final exists = await File(path).exists();
          if (mounted) {
            setState(() {
              _localPaths[url] = path;
              _localFilesExist[url] = exists;
            });
          }
        }
      }
    }
  }

  Future<bool> _downloadFile(String url, String displayName) async {
    if (mounted) {
      setState(() => _downloadProgress[url] = 0.01);
    }

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
    if (_downloadProgress.containsKey(url) || _localFilesExist[url] == true) {
      return;
    }

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
          const SnackBar(content: Text('Failed to download or open file')),
        );
      }
    }
  }

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
      await _audioPlayer.play(DeviceFileSource(localPath));
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

    if (path != null) {
      final file = File(path);
      if (await file.exists() && _firmId != null) {
        setState(() => _isUploading = true);
        final url = await SupabaseService.uploadChambersAttachment(
          file: file,
          firmId: _firmId!,
        );
        if (url != null) {
          await SupabaseService.postChambersAttachment(
            firmId: _firmId!,
            message: '🎤 Voice message (${_formatDuration(_recordDuration)})',
            url: url,
            type: 'audio',
            senderName: _profile?.fullName ?? 'Team Member',
          );
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
        const SnackBar(content: Text('Downloading to save to device...')),
      );

      if (Platform.isAndroid || Platform.isIOS) {
        if (msg.attachmentType == 'image' || msg.attachmentType == 'video') {
          final status = await Permission.photos.request();
          if (!status.isGranted) {
            final storageStatus = await Permission.storage.request();
            if (!storageStatus.isGranted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permission denied to save media to gallery.'),
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
                content: Text('Permission denied to write to storage.'),
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
          throw Exception('Download failed');
        }
      }

      if (msg.attachmentType == 'image' || msg.attachmentType == 'video') {
        final result = await ImageGallerySaverPlus.saveFile(tempPath);
        if (result != null && (result['isSuccess'] == true || result == true)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Saved successfully to Gallery! 📥'),
              ),
            );
          }
        } else {
          throw Exception('Gallery saving failed');
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
              const SnackBar(content: Text('Saved successfully to Downloads! 📂')),
            );
          }
        } else {
          throw Exception('Could not resolve downloads directory');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  // ─── Long-press message options sheet ───────────────
  void _showMessageOptions(CaseComment msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    Icons.reply_rounded,
                    color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
                  ),
                  title: Text(
                    'Reply',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replyingTo = msg;
                    });
                  },
                ),
                if (msg.attachmentUrl == null)
                  ListTile(
                    leading: Icon(
                      Icons.copy_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
                    ),
                    title: Text(
                      'Copy Text',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      Clipboard.setData(ClipboardData(text: msg.message));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                if (msg.attachmentUrl != null)
                  ListTile(
                    leading: Icon(
                      Icons.download_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
                    ),
                    title: Text(
                      'Save to Device',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _saveAttachmentToDevice(msg);
                    },
                  ),
                if (isMe)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_rounded,
                      color: Color(0xFFEF4444),
                    ),
                    title: Text(
                      'Delete message',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (dial) => AlertDialog(
                              backgroundColor:
                                  isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                              title: Text(
                                'Delete Message?',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              content: Text(
                                'Are you sure you want to delete this message?',
                                style: GoogleFonts.inter(
                                  color:
                                      isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dial, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(dial, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Color(0xFFEF4444)),
                                  ),
                                ),
                              ],
                            ),
                      );
                      if (confirm == true) {
                        try {
                          await SupabaseService.deleteDiscussion(msg.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Message deleted')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Delete failed: $e')),
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
        previewMsg.attachmentUrl != null
            ? (previewMsg.attachmentType == 'image'
                ? '📷 Photo'
                : (previewMsg.attachmentType == 'video'
                    ? '🎥 Video'
                    : '📄 Document'))
            : previewMsg.message;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      previewMsg.senderName ?? 'Team Member',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      previewText,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
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
            Container(width: 3, height: 36, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.replyToSender ?? 'Advocate',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    msg.replyToMessage ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
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

  void _scrollToMessage(String replyToId) {
    final idx = _currentMessagesList.indexWhere((m) => m.id == replyToId);
    if (idx != -1) {
      final offset = idx * 90.0;
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Widget _buildSwipeToReply({
    required Widget child,
    required CaseComment message,
  }) {
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
        child: const Icon(Icons.reply_rounded, color: Color(0xFF4F46E5)),
      ),
      child: child,
    );
  }

  // ─── MESSAGE BUBBLE ─────────────────────────────────
  Widget _buildBubble(CaseComment msg, bool isMe, bool isDark) {
    final bubbleColor =
        isMe
            ? (isDark ? const Color(0xFF4F46E5) : const Color(0xFFEEF2FF))
            : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final metaColor = isMe
        ? (isDark ? Colors.white54 : const Color(0xFF64748B))
        : (isDark ? Colors.white38 : const Color(0xFF94A3B8));

    // Custom sender name colors for group chats to identify who's talking
    final List<Color> nameColors = [
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.blue,
      Colors.pink,
      Colors.amber,
      Colors.teal,
      Colors.purple,
    ];
    final senderColor = nameColors[msg.senderId.hashCode % nameColors.length];

    final bubbleWidget = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isMe),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isMe
                  ? Colors.transparent
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe) ...[
                  Text(
                    msg.senderName ?? 'Team Member',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: senderColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (msg.hasReply) _buildQuotedReplyBox(msg, isDark),
                if (msg.attachmentUrl != null) ...[
                  if (msg.attachmentType == 'image')
                    _buildImageBubble(msg, isDark)
                  else if (msg.attachmentType == 'video')
                    _buildVideoBubble(msg, isDark)
                  else if (msg.attachmentType == 'audio' ||
                      msg.attachmentType == 'voice')
                    _buildVoiceBubble(msg, isMe, isDark)
                  else
                    _buildDocumentBubble(msg, isMe, isDark),
                  const SizedBox(height: 6),
                ],
                if (msg.attachmentUrl == null)
                  Text(
                    msg.message,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(msg.createdAt.toLocal()),
                      style: GoogleFonts.inter(fontSize: 10, color: metaColor, fontWeight: FontWeight.w500),
                    ),
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

  // ─── IMAGE BUBBLE ──────────────────────────────────
  Widget _buildImageBubble(CaseComment msg, bool isDark) {
    final url = msg.attachmentUrl!;
    final localExists = _localFilesExist[url] == true;
    final localPath = _localPaths[url];

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
        borderRadius: BorderRadius.circular(12),
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value:
                  progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
              color: const Color(0xFF4F46E5),
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
              borderRadius: BorderRadius.circular(12),
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

  // ─── VIDEO BUBBLE ──────────────────────────────────
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
                      color: const Color(0xFF4F46E5),
                      strokeWidth: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Downloading video...',
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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tap to Play Video',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ─── VOICE MESSAGE BUBBLE ──────────────────────────
  Widget _buildVoiceBubble(CaseComment msg, bool isMe, bool isDark) {
    final url = msg.attachmentUrl!;
    final isPlayingThis = _playingUrl == url;
    final isPlaying = isPlayingThis && _playerState == PlayerState.playing;

    double progressValue = 0.0;
    if (isPlayingThis && _audioDuration.inMilliseconds > 0) {
      progressValue =
          _audioPosition.inMilliseconds / _audioDuration.inMilliseconds;
    }

    String durationText = '0:00';
    if (isPlayingThis && _audioDuration != Duration.zero) {
      final rem = _audioDuration - _audioPosition;
      final m = rem.inMinutes;
      final s = rem.inSeconds % 60;
      durationText = '$m:${s.toString().padLeft(2, '0')}';
    } else {
      final reg = RegExp(r'\((\d+:\d+)\)');
      final match = reg.firstMatch(msg.message);
      if (match != null) {
        durationText = match.group(1) ?? '0:00';
      }
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _playVoice(url),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isMe ? Colors.white24 : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isMe ? Colors.white : const Color(0xFF4F46E5),
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: isMe ? Colors.white : const Color(0xFF4F46E5),
                    inactiveTrackColor: isMe ? Colors.white30 : Colors.grey[300],
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    thumbColor: isMe ? Colors.white : const Color(0xFF4F46E5),
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
                          color: isMe ? Colors.white70 : Colors.black45,
                        ),
                      ),
                      const Icon(
                        Icons.mic_rounded,
                        size: 14,
                        color: Color(0xFF10B981),
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

  // ─── DOCUMENT BUBBLE ────────────────────────────────
  Widget _buildDocumentBubble(CaseComment msg, bool isMe, bool isDark) {
    final url = msg.attachmentUrl!;
    final name = msg.message.replaceFirst('📄 ', '');
    final ext = url.split('.').last.split('?').first.toLowerCase();
    final isDownloading = _downloadProgress.containsKey(url);

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isMe ? Colors.black12 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _docColor(ext).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: isDownloading
                ? Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _docColor(ext),
                    ),
                  )
                : Icon(_docIcon(ext), color: _docColor(ext), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _downloadAndOpen(url, name),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ext.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
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
        return const Color(0xFF4F46E5);
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
      _typingChannel!.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': _profile!.id,
          'user_name': _profile!.fullName,
          'is_typing': true,
        },
      );
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      if (_amITyping) {
        _amITyping = false;
        _typingChannel?.sendBroadcastMessage(
          event: 'typing',
          payload: {
            'user_id': _profile!.id,
            'user_name': _profile!.fullName,
            'is_typing': false,
          },
        );
      }
    });
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Share Attachment',
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
                        'Camera',
                        Colors.pink,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'camera');
                        },
                      ),
                      _attachOption(
                        Icons.photo_library_rounded,
                        'Gallery',
                        Colors.purple,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'gallery');
                        },
                      ),
                      _attachOption(
                        Icons.video_library_rounded,
                        'Video',
                        Colors.deepPurple,
                        () {
                          Navigator.pop(ctx);
                          _sendAttachment(type: 'video');
                        },
                      ),
                      _attachOption(
                        Icons.description_rounded,
                        'Document',
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
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_profile == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    final typingText = _typingUsers.isEmpty
        ? null
        : _typingUsers.length == 1
            ? '${_typingUsers.first} is typing...'
            : '${_typingUsers.length} members typing...';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        leadingWidth: 40,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digital Chambers',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  typingText != null
                      ? Text(
                          typingText,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Text(
                          'Team Discussion',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final firmId = _firmId;
                if (firmId == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  );
                }
                final discussionsAsync = ref.watch(firmNoticesProvider(firmId));

                return discussionsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (messages) {
                    // Combine database stream + local optimistic posts
                    final combined = <CaseComment>[];
                    combined.addAll(messages);
                    for (final opt in _optimisticNotices) {
                      if (!messages.any((m) => m.id == opt.id)) {
                        combined.add(opt);
                      }
                    }

                    combined.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                    _currentMessagesList = combined;

                    if (combined.isEmpty) {
                      return _buildEmptyState(isDark);
                    }

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _checkLocalFiles(combined);
                      }
                    });

                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                    );

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: combined.length,
                      itemBuilder: (context, index) {
                        final msg = combined[index];
                        final isMe = msg.senderId == _profile?.id;

                        Widget? dateSeparator;
                        if (index == 0 ||
                            !_isSameDay(
                              combined[index - 1].createdAt,
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
                );
              },
            ),
          ),
          _buildReplyPreviewBar(isDark),
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    final showMic = _msgController.text.trim().isEmpty;

    if (_isRecording) {
      return Container(
        padding: EdgeInsets.only(
          left: 8,
          right: 8,
          top: 8,
          bottom:
              MediaQuery.of(context).viewInsets.bottom > 0
                  ? 8
                  : MediaQuery.of(context).padding.bottom + 8,
        ),
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fiber_manual_record,
                      color: Color(0xFFEF4444),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_recordDuration),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recording voice...',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 26,
              ),
              onPressed: _cancelRecording,
            ),
            const SizedBox(width: 8),
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                ),
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
        left: 8,
        right: 8,
        top: 8,
        bottom:
            MediaQuery.of(context).viewInsets.bottom > 0
                ? 8
                : MediaQuery.of(context).padding.bottom + 8,
      ),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      size: 22,
                      color: Color(0xFF4F46E5),
                    ),
                    onPressed: _isUploading ? null : _showAttachmentSheet,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      maxLines: 4,
                      minLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      textInputAction: TextInputAction.newline,
                      onChanged: (val) {
                        _onTextChanged(val);
                        setState(() {});
                      },
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.inter(
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
                  IconButton(
                    icon: Icon(
                      Icons.camera_alt_rounded,
                      size: 22,
                      color: Color(0xFF4F46E5),
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
          const SizedBox(width: 8),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                showMic ? Icons.mic_rounded : Icons.send_rounded,
                size: 20,
                color: Colors.white,
              ),
              onPressed: showMic ? _startRecording : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF1E293B)
                : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: Text(
        _formatDateLabel(date),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
      ),
    );
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;

    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    if (diff < 7) return DateFormat('EEEE').format(date).toUpperCase();
    return DateFormat('dd MMM yyyy').format(date).toUpperCase();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.forum_rounded,
              size: 40,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Digital Chambers Room',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation with your team.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
