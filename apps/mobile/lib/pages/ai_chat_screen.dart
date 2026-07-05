import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/gemini_service.dart';
import '../services/analytics_service.dart';
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
  File? _pendingFile; // File queued for sending (image or document)
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
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

    final prompt =
        text.trim().isEmpty
            ? (fileToSend != null && !_isImageFile(fileToSend.path)
                ? 'Analyze this document'
                : 'Analyze this image')
            : text.trim();

    // Use streaming for a ChatGPT-like word-by-word experience
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

    // Track AI query in analytics
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
        'jpg', 'jpeg', 'png', 'webp', 'gif', // Images
        'pdf', // PDF documents
        'doc', 'docx', // Word documents
        'xls', 'xlsx', // Excel files
        'txt', 'csv', // Text files
        'ppt', 'pptx', // Presentations
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
      shape: const RoundedRectangleBorder(
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
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachOption(
                      Icons.camera_alt_rounded,
                      'Camera',
                      const Color(0xFFEC4899),
                      () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    _buildAttachOption(
                      Icons.photo_library_rounded,
                      'Gallery',
                      const Color(0xFF8B5CF6),
                      () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                    _buildAttachOption(
                      Icons.description_rounded,
                      'Documents',
                      const Color(0xFF3B82F6),
                      () {
                        Navigator.pop(ctx);
                        _pickFile();
                      },
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

  // ─── Session Drawer Helpers ──────────────────────────────

  Future<void> _onNewChat() async {
    Navigator.of(context).pop(); // Close drawer
    await _gemini.startNewChat();
    if (mounted) setState(() {});
  }

  Future<void> _onSelectSession(ChatSession session) async {
    Navigator.of(context).pop(); // Close drawer
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

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 2) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final messages = _gemini.history;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
      drawer: _buildChatDrawer(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child:
                  _isLoadingHistory
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.accent,
                            strokeWidth: 2,
                          ),
                        )
                      : messages.isEmpty
                          ? _buildWelcomeView(isDark)
                          : _buildChatList(isDark, messages),
            ),
            // Pending image preview
            if (_pendingFile != null) _buildFilePreview(isDark),
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  // ─── Chat History Drawer (Sidebar) ──────────────────────

  Widget _buildChatDrawer(bool isDark) {
    final sessions = _gemini.sessions;
    final currentId = _gemini.currentSessionId;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F0F18) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20.r)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 34.w,
                    height: 34.h,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
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
                  Text(
                    'Chat History',
                    style: GoogleFonts.outfit(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // ── New Chat Button ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: InkWell(
                onTap: _onNewChat,
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF818CF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'New Chat',
                        style: GoogleFonts.inter(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 8.h),

            // ── Section header ──
            if (sessions.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'RECENTS',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFF475569)
                          : const Color(0xFF94A3B8),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),

            // ── Session list ──
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: isDark
                                ? const Color(0xFF232330)
                                : const Color(0xFFE2E8F0),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'No conversations yet',
                            style: GoogleFonts.inter(
                              fontSize: 13.sp,
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isActive = session.id == currentId;
                        return _buildSessionTile(
                          session,
                          isActive,
                          isDark,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(
    ChatSession session,
    bool isActive,
    bool isDark,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Dismissible(
        key: Key(session.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20.w),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.red,
            size: 22,
          ),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              title: const Text('Delete Chat?'),
              content: Text(
                'Delete "${session.title}"? This cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) async {
          await _gemini.deleteSession(session.id);
          if (mounted) setState(() {});
        },
        child: InkWell(
          onTap: () => _onSelectSession(session),
          onLongPress: () => _onDeleteSession(session),
          borderRadius: BorderRadius.circular(12.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isActive
                  ? (isDark
                      ? const Color(0xFF1E1E2E)
                      : const Color(0xFFEEF2FF))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
              border: isActive
                  ? Border.all(
                      color: isDark
                          ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                          : const Color(0xFF6366F1).withValues(alpha: 0.2),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isActive
                      ? Icons.chat_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: isActive
                      ? const Color(0xFF6366F1)
                      : (isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8)),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? (isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A))
                              : (isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569)),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _formatTimeAgo(session.updatedAt),
                        style: GoogleFonts.inter(
                          fontSize: 11.sp,
                          color: isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────

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
          // Hamburger menu button to open drawer
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
                        color:
                            isDark
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
          // New chat shortcut
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
                  builder:
                      (ctx) => AlertDialog(
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
                              // Refresh sessions list
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

  Widget _buildWelcomeView(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.r),
      child: Column(
        children: [
          SizedBox(height: 24.h),
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF22D3EE),
                  Color(0xFF34D399),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 36,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'CaseFlow AI',
            style: GoogleFonts.outfit(
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your expert Indian legal assistant.\nAsk questions or share images of legal documents.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5.h,
            ),
          ),
          SizedBox(height: 16.h),
          // Image analysis hint
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.image_search_rounded,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
                SizedBox(width: 8.w),
                Text(
                  '📸 Send photos of court orders, FIRs, or legal docs!',
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),
          Text(
            'TRY ASKING',
            style: GoogleFonts.inter(
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              letterSpacing: 2,
            ),
          ),
          SizedBox(height: 16.h),
          ...GeminiService.suggestedPrompts.map(
            (prompt) => _buildSuggestionCard(prompt, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, String> prompt, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: InkWell(
        onTap: () => _sendMessage(prompt['prompt']!),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161620) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Text(prompt['icon']!, style: const TextStyle(fontSize: 22.sp)),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt['title']!,
                      style: GoogleFonts.inter(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      prompt['prompt']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color:
                            isDark
                                ? const Color(0xFF64748B)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color:
                    isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
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
        final isUser = msg.role == 'user';
        return _buildMessageBubble(msg, isUser, isDark);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isUser, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
                ),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
            SizedBox(width: 10.w),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color:
                    isUser
                        ? AppTheme.accent
                        : isDark
                        ? const Color(0xFF1E1E2E)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18.r),
                  topRight: Radius.circular(18.r),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border:
                    isUser
                        ? null
                        : Border.all(
                          color:
                              isDark
                                  ? const Color(0xFF2D2D3F)
                                  : const Color(0xFFE2E8F0),
                        ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child:
                  msg.isLoading
                      ? _buildTypingIndicator()
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Show attached image in user bubble
                          if (isUser && msg.hasImage) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child:
                                  msg.imagePath != null
                                      ? Image.file(
                                        File(msg.imagePath!),
                                        width: 200.w,
                                        height: 150.h,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => Container(
                                              width: 200.w,
                                              height: 60.h,
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: Icon(Icons.broken_image),
                                              ),
                                            ),
                                      )
                                      : const SizedBox.shrink(),
                            ),
                            SizedBox(height: 8.h),
                          ],
                          _buildMessageContent(msg, isUser, isDark),
                          if (!isUser) ...[
                            SizedBox(height: 8.h),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildActionChip(
                                  Icons.copy_rounded,
                                  'Copy',
                                  () {
                                    Clipboard.setData(
                                      ClipboardData(text: msg.text),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'Copied to clipboard',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        duration: const Duration(
                                          milliseconds: 1500,
                                        ),
                                      ),
                                    );
                                  },
                                  isDark,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 10.w),
            Container(
              width: 32.w,
              height: 32.h,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                Icons.person_rounded,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionChip(
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF232330) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            SizedBox(width: 5.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg, bool isUser, bool isDark) {
    if (isUser) {
      return SelectableText(
        msg.text,
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          height: 1.6.h,
          color: Colors.white,
        ),
      );
    }

    // Parse Gen UI tags: <genui-([a-z0-9\-]+)([^>]*)\/>
    final regex = RegExp(r'<genui-([a-z0-9\-]+)\s*([^>]*)\/>');
    final matches = regex.allMatches(msg.text);

    if (matches.isEmpty) {
      return SelectableText(
        msg.text,
        style: GoogleFonts.inter(
          fontSize: 14.sp,
          height: 1.6.h,
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
        ),
      );
    }

    final children = <Widget>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final textBefore = msg.text.substring(lastEnd, match.start).trim();
        if (textBefore.isNotEmpty) {
          children.add(
            SelectableText(
              textBefore,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                height: 1.6.h,
                color:
                    isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
          );
          children.add(SizedBox(height: 12.h));
        }
      }

      final tagType = match.group(1);
      final attrString = match.group(2) ?? '';
      final attrs = _parseAttributes(attrString);

      switch (tagType) {
        case 'case':
          children.add(_buildGenUiCaseCard(attrs, isDark));
          break;
        case 'payment':
          children.add(_buildGenUiPaymentCard(attrs, isDark));
          break;
        case 'calculators':
          children.add(_buildGenUiCalculatorsCard(isDark));
          break;
        case 'section':
          children.add(_buildGenUiSectionCard(attrs, isDark));
          break;
        default:
          children.add(
            Text(
              '[Unknown Gen UI Widget: $tagType]',
              style: const TextStyle(color: Colors.red),
            ),
          );
      }

      children.add(SizedBox(height: 12.h));
      lastEnd = match.end;
    }

    if (lastEnd < msg.text.length) {
      final textAfter = msg.text.substring(lastEnd).trim();
      if (textAfter.isNotEmpty) {
        children.add(
          SelectableText(
            textAfter,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              height: 1.6.h,
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Map<String, String> _parseAttributes(String attrString) {
    final Map<String, String> attrs = {};
    final regex = RegExp(r'([a-zA-Z0-9_]+)="([^"]*)"');
    for (final match in regex.allMatches(attrString)) {
      attrs[match.group(1)!] = match.group(2)!;
    }
    return attrs;
  }

  Widget _buildGenUiCaseCard(Map<String, String> attrs, bool isDark) {
    final title = attrs['title'] ?? 'Unknown Case';
    final cnr = attrs['cnr'] ?? 'N/A';
    final court = attrs['court'] ?? 'Unknown Court';
    final nextHearing = attrs['nextHearing'] ?? '';
    final status = attrs['status'] ?? '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  size: 16,
                  color: Color(0xFF3B82F6),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'CNR: $cnr',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Court: $court',
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (cnr != 'N/A') {
                  context.go('/track-case?text=$cnr');
                }
              },
              icon: const Icon(Icons.search_rounded, size: 14),
              label: const Text('Track this Case'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenUiPaymentCard(Map<String, String> attrs, bool isDark) {
    final title = attrs['caseTitle'] ?? 'Payment';
    final total = attrs['total'] ?? '0';
    final paid = attrs['paid'] ?? '0';
    final balance = attrs['balance'] ?? '0';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Icon(
                  Icons.currency_rupee_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paid',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    '₹$paid',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Balance',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  Text(
                    '₹$balance',
                    style: GoogleFonts.inter(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenUiCalculatorsCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Popular Calculators',
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCalcChip(
                'Court Fee',
                Icons.account_balance_rounded,
                isDark,
                'court-fee',
              ),
              _buildCalcChip(
                'Limitation',
                Icons.timer_rounded,
                isDark,
                'limitation',
              ),
              _buildCalcChip(
                'Maintenance',
                Icons.family_restroom_rounded,
                isDark,
                'maintenance_calculator',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalcChip(
    String label,
    IconData icon,
    bool isDark,
    String toolId,
  ) {
    return InkWell(
      onTap: () {
        context.go('/citizen-tools?tool=$toolId');
      },
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF6366F1)),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenUiSectionCard(Map<String, String> attrs, bool isDark) {
    final act = attrs['act'] ?? 'Bare Act';
    final section = attrs['section'] ?? '';
    final title = attrs['title'] ?? '';
    final content = attrs['content'] ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12.r),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 14,
                  color: Color(0xFFD4AF37),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    '$act - Section $section',
                    style: GoogleFonts.inter(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                ],
                Text(
                  content,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    height: 1.5.h,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        SizedBox(width: 4.w),
        _buildDot(1),
        SizedBox(width: 4.w),
        _buildDot(2),
        SizedBox(width: 8.w),
        Text(
          'Thinking...',
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: const Color(0xFF94A3B8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8.w,
          height: 8.h,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.4 + (value * 0.6)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  // Pending file preview strip (images + documents)
  Widget _buildFilePreview(bool isDark) {
    final isImage = _isImageFile(_pendingFile!.path);
    final fileName = p.basename(_pendingFile!.path);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              if (isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: Image.file(
                    _pendingFile!,
                    width: 60.w,
                    height: 60.h,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getFileIcon(fileName),
                        color: const Color(0xFF6366F1),
                        size: 24,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        p.extension(fileName).toUpperCase().replaceAll('.', ''),
                        style: GoogleFonts.inter(
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              Positioned(
                top: -4,
                right: -4,
                child: InkWell(
                  onTap: () => setState(() => _pendingFile = null),
                  child: Container(
                    width: 22.w,
                    height: 22.h,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isImage ? 'Image attached' : fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  isImage
                      ? 'Add a message or tap send'
                      : 'Document ready — add a message or tap send',
                  style: GoogleFonts.inter(
                    fontSize: 11.sp,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.article_rounded;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_rounded;
      case 'txt':
        return Icons.text_snippet_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
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
      child: Row(
        children: [
          // Attachment button
          IconButton(
            onPressed: _isSending ? null : _showAttachmentOptions,
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color:
                  _pendingFile != null
                      ? const Color(0xFF6366F1)
                      : isDark
                      ? const Color(0xFF475569)
                      : const Color(0xFF94A3B8),
              size: 24,
            ),
          ),
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF232330)
                          : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (text) => _sendMessage(text),
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText:
                      _pendingFile != null
                          ? 'Describe what to analyze...'
                          : 'Ask about any Indian law...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color:
                        isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              gradient:
                  _isSending
                      ? null
                      : const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF2563EB)],
                      ),
              color:
                  _isSending
                      ? (isDark
                          ? const Color(0xFF232330)
                          : const Color(0xFFE2E8F0))
                      : null,
              borderRadius: BorderRadius.circular(22.r),
            ),
            child: IconButton(
              onPressed:
                  _isSending ? null : () => _sendMessage(_controller.text),
              icon:
                  _isSending
                      ? SizedBox(
                        width: 18.w,
                        height: 18.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? Colors.white54 : Colors.black26,
                        ),
                      )
                      : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
