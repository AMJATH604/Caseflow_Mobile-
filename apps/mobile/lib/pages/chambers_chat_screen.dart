import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
import '../components/chat/chat_widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  // Sender name colors for group identity
  static const List<Color> _nameColors = [
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.blue,
    Colors.pink,
    Colors.amber,
    Colors.teal,
    Colors.purple,
  ];

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
                if (userName != null) _typingUsers.add(userName);
              } else {
                if (userName != null) _typingUsers.remove(userName);
              }
            });
          },
        )
        .subscribe();
  }

  void _initAudioPlayerListeners() {
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _audioPosition = pos);
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _audioDuration = dur);
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
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
      _replyingTo = null;
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
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'ppt', 'pptx',
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

      setState(() => _replyingTo = null);

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
        setState(() => _downloadProgress.remove(url));
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
              child: isLocal
                  ? Image.file(File(pathOrUrl), fit: BoxFit.contain)
                  : Image.network(
                      pathOrUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
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
          setState(() => _recordDuration++);
        });
      }
    } catch (e) {
      debugPrint('Record start error: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);

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
              const SnackBar(content: Text('Saved successfully to Gallery! 📥')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
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

  // ─── Audio duration text for voice bubbles ───────────
  String? _getAudioDurationText() {
    if (_audioDuration == Duration.zero) return null;
    final rem = _audioDuration - _audioPosition;
    final m = rem.inMinutes;
    final s = rem.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ─── BUILD ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_profile == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
        body: Center(
          child: CircularProgressIndicator(
            color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
          ),
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
        backgroundColor: isDark ? const Color(0xFF202C33) : const Color(0xFF008069),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 28,
        leading: Padding(
          padding: EdgeInsets.only(left: 4.w),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF00A884) : Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digital Chambers',
                    style: GoogleFonts.inter(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  typingText != null
                      ? Text(
                          typingText,
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: const Color(0xFFD1F4CC),
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      : Text(
                          'Team Discussion',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
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
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
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
                  return Center(
                    child: CircularProgressIndicator(
                      color: isDark ? const Color(0xFF00A884) : const Color(0xFF008069),
                    ),
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
                      if (mounted) _checkLocalFiles(combined);
                    });
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _scrollToBottom(),
                    );

                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      itemCount: combined.length,
                      itemBuilder: (context, index) {
                        final msg = combined[index];
                        final isMe = msg.senderId == _profile?.id;
                        final senderColor = _nameColors[msg.senderId.hashCode % _nameColors.length];

                        Widget? dateSeparator;
                        if (index == 0 ||
                            !ChatDateSeparator.isSameDay(
                              combined[index - 1].createdAt,
                              msg.createdAt,
                            )) {
                          dateSeparator = ChatDateSeparator(
                            date: msg.createdAt,
                            isDark: isDark,
                          );
                        }

                        final bubble = ChatBubble<CaseComment>(
                          message: msg,
                          isMe: isMe,
                          isDark: isDark,
                          senderName: msg.senderName ?? 'Team Member',
                          senderNameColor: senderColor,
                          playingUrl: _playingUrl,
                          isPlaying: _playerState == PlayerState.playing,
                          audioProgress: _playingUrl == msg.attachmentUrl &&
                                  _audioDuration.inMilliseconds > 0
                              ? _audioPosition.inMilliseconds /
                                  _audioDuration.inMilliseconds
                              : 0.0,
                          audioDurationText:
                              _playingUrl == msg.attachmentUrl
                                  ? _getAudioDurationText()
                                  : null,
                          downloadProgress: _downloadProgress,
                          localFilesExist: _localFilesExist,
                          localPaths: _localPaths,
                          onLongPress: () => ChatMessageOptions.show<CaseComment>(
                            context,
                            message: msg,
                            isMe: isMe,
                            isDark: isDark,
                            onReply: () => setState(() => _replyingTo = msg),
                            onSave: msg.hasAttachment
                                ? () => _saveAttachmentToDevice(msg)
                                : null,
                            onDelete: isMe
                                ? () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dial) => AlertDialog(
                                        backgroundColor: isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white,
                                        title: Text(
                                          'Delete Message?',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        content: Text(
                                          'Are you sure you want to delete this message?',
                                          style: GoogleFonts.inter(
                                            color: isDark
                                                ? Colors.white70
                                                : const Color(0xFF475569),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dial, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(dial, true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await SupabaseService.deleteDiscussion(
                                          msg.id,
                                        );
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Message deleted'),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Delete failed: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  }
                                : null,
                          ),
                          onReplyTap: msg.replyToId != null
                              ? () {
                                  final idx = _currentMessagesList
                                      .indexWhere((m) => m.id == msg.replyToId);
                                  if (idx != -1) {
                                    final offset = idx * 90.0;
                                    _scrollController.animateTo(
                                      offset.clamp(0.0,
                                          _scrollController.position.maxScrollExtent),
                                      duration: const Duration(milliseconds: 500),
                                      curve: Curves.easeInOutCubic,
                                    );
                                  }
                                }
                              : null,
                          onImageTap: (urlOrPath) {
                            final isLocal = _localFilesExist[msg.attachmentUrl] == true &&
                                _localPaths[msg.attachmentUrl] != null;
                            _openImageViewer(
                              isLocal ? _localPaths[msg.attachmentUrl]! : msg.attachmentUrl!,
                              isLocal: isLocal,
                            );
                          },
                          onVideoTap: (url) =>
                              _downloadAndOpen(url, 'Video.mp4'),
                          onPlayVoice: _playVoice,
                          onDocumentTap: _downloadAndOpen,
                          onSaveAttachment: (msg) => _saveAttachmentToDevice(msg),
                          onDownloadInBackground: _downloadInBackground,
                        );

                        // Wrap with swipe-to-reply
                        final swipeable = Dismissible(
                          key: Key('reply_${msg.id}'),
                          direction: DismissDirection.startToEnd,
                          confirmDismiss: (direction) async {
                            setState(() => _replyingTo = msg);
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(left: 16.w),
                            child: const Icon(
                              Icons.reply_rounded,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                          child: bubble,
                        );

                        return Column(
                          children: [
                            if (dateSeparator != null) dateSeparator,
                            swipeable,
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Reply preview bar
          if (_replyingTo != null)
            ChatReplyPreview(
              senderName: _replyingTo!.senderName ?? 'Team Member',
              previewText: _replyingTo!.hasAttachment
                  ? (_replyingTo!.isImage
                      ? '📷 Photo'
                      : (_replyingTo!.isVideo
                          ? '🎥 Video'
                          : '📄 Document'))
                  : _replyingTo!.message,
              isDark: isDark,
              onClose: () => setState(() => _replyingTo = null),
            ),
          // Input bar
          ChatInputBar(
            controller: _msgController,
            isDark: isDark,
            isUploading: _isUploading,
            isRecording: _isRecording,
            recordDuration: _recordDuration,
            onSend: _sendMessage,
            onAttach: () => ChatAttachmentSheet.show(
              context,
              onSelect: (type) => _sendAttachment(type: type),
            ),
            onCamera: () => _sendAttachment(type: 'camera'),
            onStartRecording: _startRecording,
            onStopRecording: _stopAndSendRecording,
            onCancelRecording: _cancelRecording,
            onTextChanged: (val) {
              _onTextChanged(val);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
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
          SizedBox(height: 16.h),
          Text(
            'Digital Chambers Room',
            style: GoogleFonts.outfit(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Start the conversation with your team.',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
