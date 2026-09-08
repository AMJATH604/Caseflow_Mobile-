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
import '../services/repositories/direct_message_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../components/profile_avatar.dart';
import '../components/chat/chat_widgets.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/fcm_service.dart';

class DmChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const DmChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen>
    with WidgetsBindingObserver {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _isUploading = false;

  // Read-receipt tracking: mark partner messages read continuously while the
  // chat is open & foregrounded (WhatsApp behaviour), not just on entry.
  bool _isForeground = true;
  bool _markingRead = false;

  // Reactions: message_id -> list of reactions, refreshed live.
  Map<String, List<MessageReaction>> _reactions = {};
  RealtimeChannel? _reactionsChannel;
  UserProfile? _myProfile;
  Map<String, dynamic>? _partnerProfile;
  Stream<List<DirectMessage>>? _messagesStream;

  DirectMessage? _replyingTo;
  List<DirectMessage> _currentMessagesList = [];
  int _lastMessageCount = 0;
  bool _showEmoji = false;

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
    WidgetsBinding.instance.addObserver(this);
    // Suppress notifications for this conversation while user is viewing it
    FcmService().activeConversationId = widget.conversationId;
    _loadChatDetails();
    _initAudioPlayerListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    // Coming back to the foreground while viewing this chat should immediately
    // mark anything that arrived while backgrounded as read.
    if (_isForeground) {
      _markPartnerMessagesReadIfNeeded(_currentMessagesList);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clear active conversation tracking
    FcmService().activeConversationId = null;
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
    if (_reactionsChannel != null) {
      Supabase.instance.client.removeChannel(_reactionsChannel!);
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

      // Initial mark-read on entry. Messages that arrive *after* this (while
      // the chat stays open) are marked read by _markPartnerMessagesReadIfNeeded
      // as the stream delivers them.
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
        _initReactionsChannel();
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

  /// Mark the partner's messages read whenever there are unread ones and the
  /// chat is open in the foreground. Called every time the message stream
  /// delivers data, so messages that arrive *while B is looking at the chat*
  /// are marked read instantly — this is what clears the unread badge and
  /// turns the sender's tick blue in real time. Guarded so it fires once per
  /// batch (the resulting is_read update re-emits the stream with no unread
  /// left, so it does not loop).
  Future<void> _markPartnerMessagesReadIfNeeded(
    List<DirectMessage> messages,
  ) async {
    if (!_isForeground || _markingRead || !mounted) return;
    final myId = _myProfile?.id;
    if (myId == null) return;
    final hasUnreadFromPartner =
        messages.any((m) => m.senderId != myId && !m.isRead);
    if (!hasUnreadFromPartner) return;

    _markingRead = true;
    try {
      await SupabaseService.markDirectMessagesRead(widget.conversationId);
    } catch (e) {
      debugPrint('Mark read error: $e');
    } finally {
      _markingRead = false;
    }
  }

  // ─── Reactions ──────────────────────────────────────
  void _initReactionsChannel() {
    _reactionsChannel = Supabase.instance.client
        .channel('dm_reactions_${widget.conversationId}');
    _reactionsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          callback: (_) => _loadReactions(),
        )
        .subscribe();
  }

  Future<void> _loadReactions() async {
    final ids = _currentMessagesList.map((m) => m.id).toList();
    if (ids.isEmpty) return;
    try {
      final map = await SupabaseService.fetchMessageReactions(
        scope: 'dm',
        messageIds: ids,
      );
      if (mounted) setState(() => _reactions = map);
    } catch (e) {
      debugPrint('Load reactions error: $e');
    }
  }

  Map<String, int> _reactionCounts(String msgId) {
    final list = _reactions[msgId];
    if (list == null || list.isEmpty) return const {};
    final counts = <String, int>{};
    for (final r in list) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    return counts;
  }

  String? _myReaction(String msgId) {
    final list = _reactions[msgId];
    if (list == null) return null;
    for (final r in list) {
      if (r.userId == _myProfile?.id) return r.emoji;
    }
    return null;
  }

  Future<void> _toggleReaction(String msgId, String emoji) async {
    try {
      await SupabaseService.toggleMessageReaction(
        scope: 'dm',
        messageId: msgId,
        emoji: emoji,
      );
      await _loadReactions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reaction failed: $e')),
        );
      }
    }
  }

  // ─── Edit message ───────────────────────────────────
  Future<void> _editMessage(DirectMessage msg) async {
    final controller = TextEditingController(text: msg.message);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newText = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Edit message',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'Edit your message'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newText != null && newText.isNotEmpty && newText != msg.message) {
      try {
        await SupabaseService.editDirectMessage(msg.id, newText);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Edit failed: $e')),
          );
        }
      }
    }
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
    setState(() => _replyingTo = null);

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
          'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'ppt', 'pptx',
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

        setState(() => _replyingTo = null);

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

    if (_loading) {
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

    if (_partnerProfile == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E1B4B),
          foregroundColor: Colors.white,
          title: const Text('Error'),
        ),
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
          isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E1B4B),
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
        title: GestureDetector(
          onTap: () {},
          child: Row(
            children: [
              Stack(
                children: [
                  ProfileAvatar(
                    avatarUrl: _partnerProfile!['avatar_url'],
                    name: partnerName,
                    radius: 19,
                  ),
                  if (_isPartnerOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF202C33) : const Color(0xFF008069),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partnerName,
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    _isPartnerTyping
                        ? Text(
                            'typing...',
                            style: GoogleFonts.inter(
                              fontSize: 12.sp,
                              color: const Color(0xFFD1F4CC),
                              fontWeight: FontWeight.w400,
                            ),
                          )
                        : _isPartnerOnline
                            ? Text(
                                'online',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  color: const Color(0xFFD1F4CC),
                                  fontWeight: FontWeight.w400,
                                ),
                              )
                            : (_partnerLastSeenAt != null
                                ? Text(
                                    _formatLastSeen(_partnerLastSeenAt!),
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : (partnerLocation.isNotEmpty
                                    ? Text(
                                        partnerLocation,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.sp,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w400,
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
                    // Mark any freshly-arrived partner messages as read while
                    // the chat is open, so the unread badge clears and the
                    // sender sees the blue tick immediately.
                    _markPartnerMessagesReadIfNeeded(messages);
                    _loadReactions();
                  }
                });
                if (messages.length > _lastMessageCount) {
                  _lastMessageCount = messages.length;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _scrollToBottom(),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == _myProfile?.id;

                    Widget? dateSeparator;
                    if (index == 0 ||
                        !ChatDateSeparator.isSameDay(
                          messages[index - 1].createdAt,
                          msg.createdAt,
                        )) {
                      dateSeparator = ChatDateSeparator(
                        date: msg.createdAt,
                        isDark: isDark,
                      );
                    }

                    final bubble = ChatBubble<DirectMessage>(
                      message: msg,
                      isMe: isMe,
                      isDark: isDark,
                      showReadReceipt: true,
                      isRead: msg.isRead,
                      isDelivered: msg.isDelivered,
                      reactionCounts: _reactionCounts(msg.id),
                      myReactionEmoji: _myReaction(msg.id),
                      onReactionTap: (emoji) => _toggleReaction(msg.id, emoji),
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
                      onLongPress: () => ChatMessageOptions.show<DirectMessage>(
                        context,
                        message: msg,
                        isMe: isMe,
                        isDark: isDark,
                        myReaction: _myReaction(msg.id),
                        onReact: (emoji) => _toggleReaction(msg.id, emoji),
                        onReply: () => setState(() => _replyingTo = msg),
                        onForward: () => ChatForwardPicker.show(
                          context,
                          messageText: msg.message,
                          attachmentUrl: msg.attachmentUrl,
                          attachmentType: msg.attachmentType,
                        ),
                        onEdit: (isMe && !msg.hasAttachment)
                            ? () => _editMessage(msg)
                            : null,
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
                                      'Are you sure you want to delete this message for everyone?',
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
                                    await SupabaseService.deleteDirectMessage(
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
                      onSaveAttachment: _saveAttachmentToDevice,
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
            ),
          ),
          // Reply preview bar
          if (_replyingTo != null)
            ChatReplyPreview(
              senderName: _replyingTo!.senderId == _myProfile?.id
                  ? _myProfile?.fullName
                  : _partnerProfile?['full_name'],
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
            onEmoji: () {
              if (_showEmoji) {
                setState(() => _showEmoji = false);
              } else {
                FocusScope.of(context).unfocus();
                setState(() => _showEmoji = true);
              }
            },
            onStartRecording: _startRecording,
            onStopRecording: _stopAndSendRecording,
            onCancelRecording: _cancelRecording,
            onTextChanged: (val) {
              if (_showEmoji) setState(() => _showEmoji = false);
              _onTextChanged(val);
              setState(() {});
            },
          ),
          if (_showEmoji)
            SizedBox(
              height: 250.h,
              child: emoji.EmojiPicker(
                textEditingController: _msgController,
                config: emoji.Config(
                  height: 250.h,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: emoji.EmojiViewConfig(
                    backgroundColor: isDark
                        ? const Color(0xFF111B21)
                        : const Color(0xFFF0F2F5),
                    columns: 7,
                    emojiSizeMax: 28 * (Platform.isIOS ? 1.2 : 1.0),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String name, bool isDark) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        margin: EdgeInsets.symmetric(horizontal: 48.w),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF202C33).withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '👋',
              style: TextStyle(fontSize: 36.sp),
            ),
            SizedBox(height: 10.h),
            Text(
              'Say hello to $name',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFE9EDEF)
                    : const Color(0xFF111B21),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Text(
              'Start a conversation now',
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: const Color(0xFF8696A0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
