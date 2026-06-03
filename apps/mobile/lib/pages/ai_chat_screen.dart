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

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final GeminiService _gemini = GeminiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isSending = false;
  File? _pendingFile; // File queued for sending (image or document)
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    await _gemini.loadHistory();
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
                ? "Analyze this document"
                : "Analyze this image")
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Attach File",
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Send images or documents for AI analysis",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachOption(
                      Icons.camera_alt_rounded,
                      "Camera",
                      const Color(0xFFEC4899),
                      () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    _buildAttachOption(
                      Icons.photo_library_rounded,
                      "Gallery",
                      const Color(0xFF8B5CF6),
                      () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                    _buildAttachOption(
                      Icons.description_rounded,
                      "Documents",
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
    final messages = _gemini.history;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child:
                  messages.isEmpty
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

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
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
                  "CaseFlow AI",
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Powered by Gemini • Vision enabled",
                      style: GoogleFonts.inter(
                        fontSize: 11,
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
          if (_gemini.history.isNotEmpty)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text("Clear Chat?"),
                        content: const Text(
                          "This will permanently delete all your AI chat history.",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _gemini.clearHistory();
                              if (mounted) setState(() {});
                            },
                            child: const Text(
                              "Clear",
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
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
              borderRadius: BorderRadius.circular(24),
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
          const SizedBox(height: 24),
          Text(
            "CaseFlow AI",
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your expert Indian legal assistant.\nAsk questions or share images of legal documents.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Image analysis hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(width: 8),
                Text(
                  "📸 Send photos of court orders, FIRs, or legal docs!",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "TRY ASKING",
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          ...GeminiService.suggestedPrompts.map(
            (prompt) => _buildSuggestionCard(prompt, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, String> prompt, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _sendMessage(prompt['prompt']!),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161620) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Text(prompt['icon']!, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt['title']!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      prompt['prompt']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF22D3EE)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    isUser
                        ? AppTheme.accent
                        : isDark
                        ? const Color(0xFF1E1E2E)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
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
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  msg.imagePath != null
                                      ? Image.file(
                                        File(msg.imagePath!),
                                        width: 200,
                                        height: 150,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, __, ___) => Container(
                                              width: 200,
                                              height: 60,
                                              color: Colors.grey[300],
                                              child: const Center(
                                                child: Icon(Icons.broken_image),
                                              ),
                                            ),
                                      )
                                      : const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          _buildMessageContent(msg, isUser, isDark),
                          if (!isUser) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildActionChip(
                                  Icons.copy_rounded,
                                  "Copy",
                                  () {
                                    Clipboard.setData(
                                      ClipboardData(text: msg.text),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          "Copied to clipboard",
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
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF232330) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF232330) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
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
          fontSize: 14,
          height: 1.6,
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
          fontSize: 14,
          height: 1.6,
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
                fontSize: 14,
                height: 1.6,
                color:
                    isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
          );
          children.add(const SizedBox(height: 12));
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
              "[Unknown Gen UI Widget: $tagType]",
              style: TextStyle(color: Colors.red),
            ),
          );
      }

      children.add(const SizedBox(height: 12));
      lastEnd = match.end;
    }

    if (lastEnd < msg.text.length) {
      final textAfter = msg.text.substring(lastEnd).trim();
      if (textAfter.isNotEmpty) {
        children.add(
          SelectableText(
            textAfter,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  size: 16,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "CNR: $cnr",
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Court: $court",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                if (cnr != 'N/A') {
                  context.go('/track-case?text=$cnr');
                }
              },
              icon: const Icon(Icons.search_rounded, size: 14),
              label: const Text("Track this Case"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.currency_rupee_rounded,
                  size: 16,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Paid",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    "₹$paid",
                    style: GoogleFonts.inter(
                      fontSize: 14,
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
                    "Balance",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                  Text(
                    "₹$balance",
                    style: GoogleFonts.inter(
                      fontSize: 14,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161620) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Popular Calculators",
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCalcChip(
                "Court Fee",
                Icons.account_balance_rounded,
                isDark,
                "court-fee",
              ),
              _buildCalcChip(
                "Limitation",
                Icons.timer_rounded,
                isDark,
                "limitation",
              ),
              _buildCalcChip(
                "Maintenance",
                Icons.family_restroom_rounded,
                isDark,
                "maintenance_calculator",
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF6366F1)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 14,
                  color: Color(0xFFD4AF37),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$act - Section $section",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  content,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
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
        const SizedBox(width: 4),
        _buildDot(1),
        const SizedBox(width: 4),
        _buildDot(2),
        const SizedBox(width: 8),
        Text(
          "Thinking...",
          style: GoogleFonts.inter(
            fontSize: 12,
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
          width: 8,
          height: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _pendingFile!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
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
                      const SizedBox(height: 2),
                      Text(
                        p.extension(fileName).toUpperCase().replaceAll('.', ''),
                        style: GoogleFonts.inter(
                          fontSize: 8,
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
                    width: 22,
                    height: 22,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isImage ? "Image attached" : fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isImage
                      ? "Add a message or tap send"
                      : "Document ready — add a message or tap send",
                  style: GoogleFonts.inter(
                    fontSize: 11,
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
        left: 8,
        right: 8,
        top: 12,
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
                borderRadius: BorderRadius.circular(24),
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
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText:
                      _pendingFile != null
                          ? "Describe what to analyze..."
                          : "Ask about any Indian law...",
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
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
          const SizedBox(width: 8),
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
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
              borderRadius: BorderRadius.circular(22),
            ),
            child: IconButton(
              onPressed:
                  _isSending ? null : () => _sendMessage(_controller.text),
              icon:
                  _isSending
                      ? SizedBox(
                        width: 18,
                        height: 18,
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
