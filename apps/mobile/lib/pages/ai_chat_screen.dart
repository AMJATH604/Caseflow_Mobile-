import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../theme/app_theme.dart';
import '../services/gemini_service.dart';
import '../services/analytics_service.dart';
import '../components/ai_chat/ai_chat_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    // The composer draws an accent ring while focused, which only appears if
    // the field's focus changes rebuild it.
    _focusNode.addListener(_onFocusChanged);
    _loadChatHistory();
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
    _controller.dispose();
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
          _scrollToBottom();
        }
      },
    );

    AnalyticsService.logAIQuerySent(hasAttachment: fileToSend != null);

    if (mounted) {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
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
    final messages = _gemini.history;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
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
            _buildHeader(isDark),
            Expanded(
              child: _isLoadingHistory
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accent,
                        strokeWidth: 2,
                      ),
                    )
                  : messages.isEmpty
                      ? AiChatWelcome(
                          isDark: isDark,
                          onSendPrompt: _sendMessage,
                        )
                      : _buildChatList(isDark, messages),
            ),
            if (_pendingFile != null)
              AiFilePreview(
                file: _pendingFile!,
                isDark: isDark,
                onRemove: () => setState(() => _pendingFile = null),
              ),
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────
  Widget _buildHeader(bool isDark) {
    final sessionTitle = _gemini.currentSessionTitle;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            icon: Icon(
              Icons.menu_rounded,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              size: 24,
            ),
            tooltip: 'Chat History',
          ),
          Container(
            width: 34.w,
            height: 34.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 18,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionTitle ?? 'CaseFlow AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 1.h),
                Row(
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      'Powered by Gemini • Vision enabled',
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await _gemini.startNewChat();
              if (mounted) setState(() {});
            },
            icon: Icon(
              Icons.edit_square,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              size: 20,
            ),
            tooltip: 'New Chat',
          ),
          if (_gemini.history.isNotEmpty)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    title: const Text('Delete Chat?'),
                    content: const Text(
                      'This will permanently delete this conversation.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _gemini.clearHistory();
                          await _gemini.fetchSessions();
                          if (mounted) setState(() {});
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: Icon(
                Icons.delete_outline_rounded,
                color: isDark ? const Color(0xFF64748B) : Colors.black38,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatList(bool isDark, List<ChatMessage> messages) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 8.w,
        right: 8.w,
        top: 12.h,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      // One rounded field holding attach, text and send — the composer shape
      // ChatGPT and Claude use. Three separate controls in a row read as a
      // form; one container reads as a place to type.
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: _focusNode.hasFocus
                ? AppTheme.accent.withValues(alpha: 0.5)
                : (isDark
                    ? const Color(0xFF232330)
                    : const Color(0xFFE2E8F0)),
            width: _focusNode.hasFocus ? 1.5 : 1,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Attach',
              onPressed: _isSending ? null : _showAttachmentOptions,
              icon: Icon(
                Icons.add_rounded,
                color: _pendingFile != null
                    ? AppTheme.accent
                    : isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                size: 22,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 6,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (text) => _sendMessage(text),
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  height: 1.45,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _pendingFile != null
                      ? 'Describe what to analyse…'
                      : 'Ask about any Indian law…',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
            SizedBox(width: 4.w),
            Padding(
              padding: EdgeInsets.only(bottom: 3.h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: _isSending
                      ? (isDark
                          ? const Color(0xFF232330)
                          : const Color(0xFFE2E8F0))
                      : AppTheme.accent,
                  borderRadius: BorderRadius.circular(17.r),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Send',
                  onPressed:
                      _isSending ? null : () => _sendMessage(_controller.text),
                  icon: _isSending
                      ? SizedBox(
                          width: 15.w,
                          height: 15.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white54 : Colors.black26,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
