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
import '../services/repositories/direct_message_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../components/profile_avatar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DmChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const DmChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _isUploading = false;
  UserProfile? _myProfile;
  Map<String, dynamic>? _partnerProfile;
  Stream<List<DirectMessage>>? _messagesStream;

  DirectMessage? _replyingTo;
  List<DirectMessage> _currentMessagesList = [];

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

  // Typing indicators & Realtime
  RealtimeChannel? _typingChannel;
  bool _isPartnerTyping = false;
  Timer? _typingDebounce;
  bool _amITyping = false;

  // Online / Last Seen
  RealtimeChannel? _presenceChannel;
  bool _isPartnerOnline = false;
  DateTime? _partnerLastSeenAt;

  // Download tracking: attachmentUrl -> progress (0.0..1.0) or null
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _loadChatDetails();
    _initAudioPlayerListeners();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _recordTimer?.cancel();
    _typingDebounce?.cancel();
    if (_typingChannel != null) {
      Supabase.instance.client.removeChannel(_typingChannel!);
    }
    if (_presenceChannel != null) {
      Supabase.instance.client.removeChannel(_presenceChannel!);
    }
    // Update own last_seen_at on leaving chat
    _updateLastSeen();
    super.dispose();
  }

  Future<void> _loadChatDetails() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      _myProfile = await SupabaseService.fetchProfile();

      // Fetch the conversation to find the partner ID
      final conv = await Supabase.instance.client
          .from('direct_conversations')
          .select()
          .eq('id', widget.conversationId)
          .single();

      final partnerId =
          conv['participant_1'] == user.id
              ? conv['participant_2']
              : conv['participant_1'];

      // Fetch partner profile (include last_seen_at)
      final partnerProfile = await Supabase.instance.client
          .from('profiles')
          .select(
            'id, full_name, avatar_url, practice_state, practice_district, last_seen_at',
          )
          .eq('id', partnerId)
          .single();

      // Parse last_seen_at
      final lastSeenRaw = partnerProfile['last_seen_at'];
      DateTime? lastSeen;
      if (lastSeenRaw != null) {
        lastSeen = DateTime.tryParse(lastSeenRaw.toString());
      }

      // Mark messages as read
      await SupabaseService.markDirectMessagesRead(widget.conversationId);

      if (mounted) {
        setState(() {
          _partnerProfile = partnerProfile;
          _partnerLastSeenAt = lastSeen;
          _messagesStream = SupabaseService.directMessagesStream(
            widget.conversationId,
          );
          _loading = false;
        });
        _initTypingChannel();
        _initPresenceChannel(partnerId);
        _updateLastSeen();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Load DM details error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _initTypingChannel() {
    _typingChannel = Supabase.instance.client.channel(
      'dm_typing_${widget.conversationId}',
    );

    _typingChannel!
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final userId = payload['user_id'] as String?;
            final isTyping = payload['is_typing'] as bool? ?? false;

            if (userId == null || userId == _myProfile?.id) return;

            setState(() {
              _isPartnerTyping = isTyping;
            });
          },
        )
        .subscribe();
  }

  /// Presence channel for online/offline detection
  void _initPresenceChannel(String partnerId) {
    final channelName = 'online_status_${widget.conversationId}';
    _presenceChannel = Supabase.instance.client.channel(
      channelName,
      opts: const RealtimeChannelConfig(self: true),
    );

    _presenceChannel!
        .onPresenceSync((payload) {
          final presences = _presenceChannel!.presenceState();
          bool partnerOnline = false;
          for (final state in presences) {
            for (final presence in state.presences) {
              if (presence.payload['user_id'] == partnerId) {
                partnerOnline = true;
                break;
              }
            }
            if (partnerOnline) break;
          }
          if (mounted && _isPartnerOnline != partnerOnline) {
            setState(() => _isPartnerOnline = partnerOnline);
          }
        })
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _presenceChannel!.track({
              'user_id': _myProfile?.id ?? '',
              'online_at': DateTime.now().toIso8601String(),
            });
          }
        });
  }

  /// Update own last_seen_at in profiles table
  Future<void> _updateLastSeen() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client
          .from('profiles')
          .update({'last_seen_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', user.id);
    } catch (_) {}
  }

  /// Format the last seen time for display
  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final local = lastSeen.toLocal();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'last seen just now';
    if (diff.inMinutes < 60) return 'last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      return 'last seen at ${DateFormat('hh:mm a').format(local)}';
    }
    if (diff.inDays == 1) {
      return 'last seen yesterday at ${DateFormat('hh:mm a').format(local)}';
    }
    return 'last seen ${DateFormat('dd/MM/yy').format(local)}';
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
    if (text.isEmpty) return;

    final replyId = _replyingTo?.id;
    final replyMessage =
        _replyingTo?.hasAttachment == true
            ? (_replyingTo!.isImage
                ? '📷 Photo'
                : (_replyingTo!.isVideo
                    ? '🎥 Video'
                    : '📄 Document'))
            : _replyingTo?.message;
    final replySender = _replyingTo?.senderId == _myProfile?.id
        ? _myProfile?.fullName
        : _partnerProfile?['full_name'];

    _msgController.clear();
    setState(() {
      _replyingTo = null; // Clear reply context
    });

    try {
      await SupabaseService.sendDirectMessage(
        widget.conversationId,
        text,
        replyToId: replyId,
        replyToMessage: replyMessage,
        replyToSender: replySender,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  // ─── Send Attachment ────────────────────────────────
  Future<void> _sendAttachment({required String type}) async {
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
      attachmentType = DirectMessageRepository.getAttachmentType(file.path);
    }

    if (file == null) return;

    setState(() => _isUploading = true);

    final url = await SupabaseService.uploadDirectMessageAttachment(
      file: file,
      conversationId: widget.conversationId,
    );

    if (url != null && attachmentType != null) {
      try {
        final replyId = _replyingTo?.id;
        final replyMessage =
            _replyingTo?.hasAttachment == true
                ? (_replyingTo!.isImage
                    ? '📷 Photo'
                    : (_replyingTo!.isVideo
                        ? '🎥 Video'
                        : '📄 Document'))
                : _replyingTo?.message;
        final replySender = _replyingTo?.senderId == _myProfile?.id
            ? _myProfile?.fullName
            : _partnerProfile?['full_name'];

        setState(() {
          _replyingTo = null;
        });

        await SupabaseService.sendDirectMessage(
          widget.conversationId,
          attachmentType == 'image'
              ? '📷 Photo'
              : (attachmentType == 'video' ? '🎥 Video' : '📄 Document'),
          attachmentUrl: url,
          attachmentType: attachmentType,
          replyToId: replyId,
          replyToMessage: replyMessage,
          replyToSender: replySender,
        );
        _scrollToBottom();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send attachment: $e')),
          );
        }
      }
    }

    if (mounted) setState(() => _isUploading = false);
  }

  // ─── Local cache / file helpers ──────────────────────
  Future<String> _getLocalFilePath(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = url.split('/').last.split('?').first;
    return '${dir.path}/$name';
  }

  void _checkLocalFiles(List<DirectMessage> messages) async {
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
      if (await file.exists()) {
        setState(() => _isUploading = true);
        final url = await SupabaseService.uploadDirectMessageAttachment(
          file: file,
          conversationId: widget.conversationId,
        );
        if (url != null) {
          await SupabaseService.sendDirectMessage(
            widget.conversationId,
            '🎤 Voice message (${_formatDuration(_recordDuration)})',
            attachmentUrl: url,
            attachmentType: 'audio',
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
  Future<void> _saveAttachmentToDevice(DirectMessage msg) async {
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
  void _showMessageOptions(DirectMessage msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12.h),
                Container(
                  width: 38.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 16.h),
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
                if (!msg.hasAttachment)
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
                if (msg.hasAttachment)
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
                      'Delete for Everyone',
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
                                'Are you sure you want to delete this message for everyone?',
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
                          await SupabaseService.deleteDirectMessage(msg.id);
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
                SizedBox(height: 8.h),
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
            ? (previewMsg.isImage
                ? '📷 Photo'
                : (previewMsg.isVideo
                    ? '🎥 Video'
                    : '📄 Document'))
            : previewMsg.message;

    final previewSender = previewMsg.senderId == _myProfile?.id
        ? _myProfile?.fullName
        : _partnerProfile?['full_name'];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 4.w,
              height: 48.h,
              decoration: const BoxDecoration(
                color: Color(0xFF4F46E5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12.r),
                  bottomLeft: Radius.circular(12.r),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      previewSender ?? 'Advocate',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4F46E5),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      previewText,
                      style: GoogleFonts.inter(
                        fontSize: 13.sp,
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
  Widget _buildQuotedReplyBox(DirectMessage msg, bool isDark) {
    return GestureDetector(
      onTap: () {
        if (msg.replyToId != null) {
          _scrollToMessage(msg.replyToId!);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Row(
          children: [
            Container(width: 3.w, height: 36.h, color: const Color(0xFF4F46E5)),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.replyToSender ?? 'Advocate',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    msg.replyToMessage ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
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
    required DirectMessage message,
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
        padding: EdgeInsets.only(left: 16.w),
        child: const Icon(Icons.reply_rounded, color: Color(0xFF4F46E5)),
      ),
      child: child,
    );
  }

  // ─── MESSAGE BUBBLE ─────────────────────────────────
  Widget _buildBubble(DirectMessage msg, bool isMe, bool isDark) {
    final bubbleColor = isMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
        : (isDark ? const Color(0xFF202C33) : Colors.white);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2C34);
    final metaColor = isMe
        ? (isDark ? Colors.white54 : const Color(0xFF667781))
        : (isDark ? Colors.white38 : const Color(0xFF667781));

    final bubbleWidget = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg, isMe),
        child: Container(
          margin: EdgeInsets.only(bottom: 6.h),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
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
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.hasReply) _buildQuotedReplyBox(msg, isDark),
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
                  SizedBox(height: 6.h),
                ],
                if (!msg.hasAttachment)
                  Text(
                    msg.message,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 14.sp,
                      height: 1.4.h,
                    ),
                  ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(msg.createdAt.toLocal()),
                      style: GoogleFonts.inter(fontSize: 10.sp, color: metaColor, fontWeight: FontWeight.w500),
                    ),
                    if (isMe) ...[
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: msg.isRead ? const Color(0xFF10B981) : metaColor,
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

  // ─── IMAGE BUBBLE ──────────────────────────────────
  Widget _buildImageBubble(DirectMessage msg, bool isDark) {
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
        borderRadius: BorderRadius.circular(12.r),
        child:
            localExists && localPath != null
                ? Image.file(
                  File(localPath),
                  width: 260.w,
                  height: 200.h,
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
      width: 260.w,
      height: 200.h,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          width: 260.w,
          height: 200.h,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey[200],
            borderRadius: BorderRadius.circular(12.r),
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
            width: 260.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12.r),
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
  Widget _buildVideoBubble(DirectMessage msg, bool isDark) {
    final isDownloading = _downloadProgress.containsKey(msg.attachmentUrl);
    final progress = _downloadProgress[msg.attachmentUrl] ?? 0.0;

    return GestureDetector(
      onTap:
          isDownloading
              ? null
              : () => _downloadAndOpen(msg.attachmentUrl!, 'Video.mp4'),
      child: Container(
        width: 260.w,
        height: 180.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
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
            width: 1.w,
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
                    width: 56.w,
                    height: 56.h,
                    child: CircularProgressIndicator(
                      value: progress > 0 ? progress : null,
                      color: const Color(0xFF4F46E5),
                      strokeWidth: 4,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Downloading video...',
                    style: TextStyle(
                      fontSize: 12.sp,
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
                    width: 64.w,
                    height: 64.h,
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
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Tap to Play Video',
                    style: TextStyle(
                      fontSize: 12.sp,
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
  Widget _buildVoiceBubble(DirectMessage msg, bool isMe, bool isDark) {
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
      width: 250.w,
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _playVoice(url),
            child: Container(
              width: 40.w,
              height: 40.h,
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
          SizedBox(width: 10.w),
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
                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        durationText,
                        style: TextStyle(
                          fontSize: 10.sp,
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
  Widget _buildDocumentBubble(DirectMessage msg, bool isMe, bool isDark) {
    final url = msg.attachmentUrl!;
    final name = msg.message.replaceFirst('📄 ', '');
    final ext = url.split('.').last.split('?').first.toLowerCase();
    final isDownloading = _downloadProgress.containsKey(url);

    return Container(
      width: 250.w,
      decoration: BoxDecoration(
        color: isMe ? Colors.black12 : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10.r),
      ),
      padding: EdgeInsets.all(8.r),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: BoxDecoration(
              color: _docColor(ext).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: isDownloading
                ? Padding(
                    padding: EdgeInsets.all(10.r),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _docColor(ext),
                    ),
                  )
                : Icon(_docIcon(ext), color: _docColor(ext), size: 24),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: GestureDetector(
              onTap: () => _downloadAndOpen(url, name),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    ext.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Download / Save button
          if (!isDownloading)
            GestureDetector(
              onTap: () => _saveAttachmentToDevice(msg),
              child: Container(
                width: 36.w,
                height: 36.h,
                decoration: BoxDecoration(
                  color: _docColor(ext).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.download_rounded,
                  color: _docColor(ext),
                  size: 20,
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
    if (_typingChannel == null || _myProfile == null) return;

    if (text.isNotEmpty && !_amITyping) {
      _amITyping = true;
      _typingChannel!.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': _myProfile!.id,
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
            'user_id': _myProfile!.id,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: EdgeInsets.all(24.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Share Attachment',
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 24.h),
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
                  SizedBox(height: 12.h),
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
      borderRadius: BorderRadius.circular(16.r),
      child: Column(
        children: [
          Container(
            width: 56.w,
            height: 56.h,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
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

    if (_loading) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
        ),
      );
    }

    if (_partnerProfile == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Failed to load advocate details.')),
      );
    }

    final partnerName = _partnerProfile!['full_name'] ?? 'Unknown Advocate';
    final partnerLocation =
        [
          _partnerProfile!['practice_district'],
          _partnerProfile!['practice_state'],
        ].where((s) => s != null).join(', ');

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B141A) : const Color(0xFFF0F2F5),
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
            ProfileAvatar(
              avatarUrl: _partnerProfile!['avatar_url'],
              name: partnerName,
              radius: 18,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partnerName,
                    style: GoogleFonts.outfit(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  _isPartnerTyping
                      ? Text(
                          'typing...',
                          style: GoogleFonts.inter(
                            fontSize: 11.sp,
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : _isPartnerOnline
                          ? Text(
                              'Online',
                              style: GoogleFonts.inter(
                                fontSize: 11.sp,
                                color: const Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : (_partnerLastSeenAt != null
                              ? Text(
                                  _formatLastSeen(_partnerLastSeenAt!),
                                  style: GoogleFonts.inter(
                                    fontSize: 11.sp,
                                    color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : (partnerLocation.isNotEmpty
                                  ? Text(
                                      partnerLocation,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.sp,
                                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : const SizedBox.shrink())),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: SizedBox(
                  width: 20.w,
                  height: 20.h,
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
            child: StreamBuilder<List<DirectMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];
                _currentMessagesList = messages;

                if (messages.isEmpty) {
                  return _buildEmptyState(partnerName, isDark);
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _checkLocalFiles(messages);
                  }
                });

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _myProfile?.id;

                    Widget? dateSeparator;
                    if (index == 0 ||
                        !_isSameDay(
                          messages[index - 1].createdAt,
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
          left: 8.w,
          right: 8.w,
          top: 8.h,
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
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.fiber_manual_record,
                      color: Color(0xFFEF4444),
                      size: 16,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      _formatDuration(_recordDuration),
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      'Recording voice...',
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFEF4444),
                size: 26,
              ),
              onPressed: _cancelRecording,
            ),
            SizedBox(width: 8.w),
            Container(
              width: 48.w,
              height: 48.h,
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
        left: 8.w,
        right: 8.w,
        top: 8.h,
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
                borderRadius: BorderRadius.circular(24.r),
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
                        fontSize: 15.sp,
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
                          fontSize: 15.sp,
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
          SizedBox(width: 8.w),
          Container(
            width: 48.w,
            height: 48.h,
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
      margin: EdgeInsets.symmetric(vertical: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF1E293B)
                : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: Text(
        _formatDateLabel(date),
        style: GoogleFonts.inter(
          fontSize: 11.sp,
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

  Widget _buildEmptyState(String name, bool isDark) {
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
              Icons.waving_hand_rounded,
              size: 40,
              color: Color(0xFF4F46E5),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Say Hello to $name',
            style: GoogleFonts.outfit(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Start the conversation now.',
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
