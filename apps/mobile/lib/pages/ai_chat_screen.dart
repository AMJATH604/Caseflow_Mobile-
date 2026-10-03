import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/gemini_service.dart';
import '../services/analytics_service.dart';
import '../components/ai_chat/ai_chat_widgets.dart';
import '../components/ai_chat/ai_palette.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AiChatScreen extends StatefulWidget {
  final String? initialSessionId;
  const AiChatScreen({super.key, this.initialSessionId});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final GeminiService _gemini = GeminiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSending = false;
  File? _pendingFile;
  bool _isLoadingHistory = true;

  /// Whether the reader is at the latest message. While they are, a
  /// streaming answer keeps the view at its end; once they scroll up to
  /// reread, it stops pulling them down and offers a jump button instead.
  bool _atBottom = true;

  @override
  void initState() {
    super.initState();
    // The composer draws an accent ring while focused, which only appears if
    // the field's focus changes rebuild it.
    _focusNode.addListener(_onFocusChanged);
    _scrollController.addListener(_onScroll);
    // The send button lights up as soon as there is something to send.
    _controller.addListener(_onTextChanged);
    _loadChatHistory();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final atBottom = pos.maxScrollExtent - pos.pixels < 120;
    if (atBottom != _atBottom) setState(() => _atBottom = atBottom);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadChatHistory() async {
    if (widget.initialSessionId != null) {
      await _gemini.fetchSessions();
      await _gemini.loadSession(widget.initialSessionId!);
    } else {
      await _gemini.loadHistory();
    }
    if (mounted) {
      setState(() => _isLoadingHistory = false);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty && _pendingFile == null) return;
    if (_isSending) return;

    final fileToSend = _pendingFile;
    _controller.clear();
    setState(() {
      _isSending = true;
      _pendingFile = null;
    });
    _scrollToBottom();

    final prompt = text.trim().isEmpty
        ? (fileToSend != null && !_isImageFile(fileToSend.path)
            ? 'Analyze this document'
            : 'Analyze this image')
        : text.trim();

    await _gemini.sendMessageStream(
      prompt,
      imageFile: fileToSend,
      onChunk: (fullText) {
        if (mounted) {
          setState(() {});
          if (_atBottom) _scrollToBottom(smooth: false);
        }
      },
    );

    AnalyticsService.logAIQuerySent(hasAttachment: fileToSend != null);

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom({bool smooth = true}) {
    Future.delayed(const Duration(milliseconds: 60), () {
      if (!_scrollController.hasClients) return;
      final end = _scrollController.position.maxScrollExtent;
      if (smooth) {
        _scrollController.animateTo(
          end,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(end);
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1024,
    );
    if (picked != null && mounted) {
      setState(() => _pendingFile = File(picked.path));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg', 'jpeg', 'png', 'webp', 'gif',
        'pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'csv',
        'ppt', 'pptx',
      ],
    );
    if (result != null && result.files.isNotEmpty && mounted) {
      setState(() => _pendingFile = File(result.files.first.path!));
    }
  }

  bool _isImageFile(String path) {
    final ext = p.extension(path).toLowerCase().replaceAll('.', '');
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'].contains(ext);
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Attach File',
                  style: GoogleFonts.outfit(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Send images or documents for AI analysis',
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachOption(
                      Icons.camera_alt_rounded, 'Camera', const Color(0xFFEC4899),
                      () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
                    ),
                    _buildAttachOption(
                      Icons.photo_library_rounded, 'Gallery', const Color(0xFF8B5CF6),
                      () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
                    ),
                    _buildAttachOption(
                      Icons.description_rounded, 'Documents', const Color(0xFF3B82F6),
                      () { Navigator.pop(ctx); _pickFile(); },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachOption(
    IconData icon, String label, Color color, VoidCallback onTap,
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

  // ─── Session Drawer Helpers ──────────────────────────
  Future<void> _onNewChat() async {
    Navigator.of(context).pop();
    await _gemini.startNewChat();
    if (mounted) setState(() {});
  }

  Future<void> _onSelectSession(ChatSession session) async {
    Navigator.of(context).pop();
    if (session.id == _gemini.currentSessionId) return;
    setState(() => _isLoadingHistory = true);
    await _gemini.loadSession(session.id);
    if (mounted) {
      setState(() => _isLoadingHistory = false);
      _scrollToBottom();
    }
  }

  Future<void> _onDeleteSession(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: const Text('Delete Chat?'),
        content: Text('Delete "${session.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _gemini.deleteSession(session.id);
      if (mounted) setState(() {});
    }
  }

  // ─── BUILD ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AiPalette(isDark);
    final messages = _gemini.history;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.bg,
      drawer: AiChatDrawer(
        isDark: isDark,
        sessions: _gemini.sessions,
        currentSessionId: _gemini.currentSessionId,
        onNewChat: _onNewChat,
        onSelectSession: _onSelectSession,
        onDeleteSession: _onDeleteSession,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(c),
            Expanded(
              child: _isLoadingHistory
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: c.muted,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : messages.isEmpty
                      ? AiChatWelcome(isDark: isDark, onSendPrompt: _sendMessage)
                      : Stack(
                          children: [
                            _buildChatList(isDark, messages),
                            if (!_atBottom)
                              Positioned(
                                bottom: 12.h,
                                left: 0,
                                right: 0,
                                child: Center(child: _buildJumpButton(c)),
                              ),
                          ],
                        ),
            ),
            if (_pendingFile != null)
              AiFilePreview(
                file: _pendingFile!,
                isDark: isDark,
                onRemove: () => setState(() => _pendingFile = null),
              ),
            _buildComposer(c),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────
  /// Three things, as in ChatGPT: history, the conversation's name, new chat.
  /// Deleting a chat lives in history (swipe or long-press), not up here.
  Widget _buildHeader(AiPalette c) {
    final title = _gemini.currentSessionTitle;
    return SizedBox(
      height: 52.h,
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: 'Chat history',
            icon: Icon(Icons.menu_rounded, color: c.ink, size: 24),
          ),
          Expanded(
            child: Text(
              (title == null || title.isEmpty || title == 'New Chat')
                  ? 'CaseFlow AI'
                  : title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
          ),
          IconButton(
            onPressed: _isSending
                ? null
                : () async {
                    await _gemini.startNewChat();
                    if (mounted) setState(() {});
                  },
            tooltip: 'New chat',
            icon: Icon(Icons.edit_square, color: c.ink, size: 21),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(bool isDark, List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 24.h),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return AiMessageBubble(
          message: msg,
          isUser: msg.role == 'user',
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildJumpButton(AiPalette c) {
    return Material(
      color: c.bg,
      shape: CircleBorder(side: BorderSide(color: c.border)),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _scrollToBottom,
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Icon(Icons.arrow_downward_rounded, size: 20, color: c.ink),
        ),
      ),
    );
  }

  // ─── Composer ────────────────────────────────────────
  /// One rounded box holding attach, text and send, floating on the page;
  /// the send button is a solid circle that lights up only when there is
  /// something to send.
  Widget _buildComposer(AiPalette c) {
    final canSend = !_isSending &&
        (_controller.text.trim().isNotEmpty || _pendingFile != null);
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 6.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(26.r),
              border: Border.all(
                color: _focusNode.hasFocus ? c.faint : c.border,
              ),
            ),
            padding: EdgeInsets.fromLTRB(4.w, 4.h, 6.w, 4.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach a photo or document',
                  onPressed: _isSending ? null : _showAttachmentOptions,
                  icon: Icon(
                    Icons.add_rounded,
                    size: 24,
                    color: _pendingFile != null ? c.ink : c.muted,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 6,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    style: GoogleFonts.inter(
                      fontSize: 15.sp,
                      height: 1.45,
                      color: c.ink,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: _pendingFile != null
                          ? 'Ask about this file'
                          : 'Message CaseFlow AI',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 15.sp,
                        color: c.faint,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
                Padding(
                  padding: EdgeInsets.only(bottom: 5.h),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 36.r,
                    height: 36.r,
                    decoration: BoxDecoration(
                      color: canSend || _isSending ? c.action : c.surfaceHigh,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: _isSending ? 'Answering…' : 'Send',
                      onPressed:
                          canSend ? () => _sendMessage(_controller.text) : null,
                      icon: _isSending
                          ? SizedBox(
                              width: 14.r,
                              height: 14.r,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.onAction,
                              ),
                            )
                          : Icon(
                              Icons.arrow_upward_rounded,
                              size: 20,
                              color: canSend ? c.onAction : c.faint,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'CaseFlow AI can make mistakes. Check important information.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 10.5.sp, color: c.faint),
          ),
        ],
      ),
    );
  }
}
