import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/cross_exam_models.dart';
import '../services/providers.dart';
import '../services/repositories/cross_exam_repository.dart';
import '../theme/app_theme.dart';

/// Question Builder and Cross-Examination Workspace for a single witness.
///
/// 100% private, local Supabase CRUD. Zero AI APIs.
class CrossExamDetailScreen extends ConsumerStatefulWidget {
  final CrossExamSession session;

  const CrossExamDetailScreen({super.key, required this.session});

  @override
  ConsumerState<CrossExamDetailScreen> createState() =>
      _CrossExamDetailScreenState();
}

class _CrossExamDetailScreenState
    extends ConsumerState<CrossExamDetailScreen> {
  late CrossExamSession _session;
  final _quickAddController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<String> _expandedQuestionIds = {};
  bool _filterOnlyKeyQuestions = false;
  bool _isAdding = false;

  static const _tagColors = <String, List<Color>>{
    'PW': [Color(0xFF2563EB), Color(0xFF3B82F6)],
    'DW': [Color(0xFFDC2626), Color(0xFFEF4444)],
    'CW': [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
  };

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final questionsAsync = ref.watch(crossExamQuestionsProvider(_session.id));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0B0F19) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context, isDark),
      body: Column(
        children: [
          _buildWitnessHeaderCard(isDark),
          Expanded(
            child: questionsAsync.when(
              data: (questions) => _buildQuestionsList(questions, isDark),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: EdgeInsets.all(24.r),
                  child: Text('Error loading questions: $e'),
                ),
              ),
            ),
          ),
          _buildQuickAddBar(isDark),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18.sp,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question Builder',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          Text(
            '${_session.witnessTag} · ${_session.witnessName}',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: _filterOnlyKeyQuestions
              ? 'Show All Questions'
              : 'Show Key Questions Only',
          icon: Icon(
            _filterOnlyKeyQuestions
                ? Icons.stars_rounded
                : Icons.stars_outlined,
            color: _filterOnlyKeyQuestions
                ? Colors.amber
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
          onPressed: () {
            setState(() {
              _filterOnlyKeyQuestions = !_filterOnlyKeyQuestions;
            });
          },
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          onSelected: (val) => _handleMenuAction(val),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export_pdf',
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf_rounded,
                      size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Export PDF Document'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit_session',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Edit Witness / Date'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'change_status',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Change Status'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete_session',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Session', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWitnessHeaderCard(bool isDark) {
    final tagPrefix = _session.witnessTagPrefix.toUpperCase();
    final colors = _tagColors[tagPrefix] ?? _tagColors['CW']!;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Tag Badge
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  _session.witnessTag.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  _session.witnessName,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Status Pill (tappable)
              InkWell(
                onTap: _showChangeStatusDialog,
                borderRadius: BorderRadius.circular(8.r),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_session.status.emoji} ${_session.status.label}',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.arrow_drop_down,
                          color: Colors.white, size: 14.sp),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Case title & Hearing Date
          Row(
            children: [
              Icon(Icons.folder_outlined,
                  size: 13.sp, color: Colors.white.withValues(alpha: 0.7)),
              SizedBox(width: 5.w),
              Expanded(
                child: Text(
                  _session.caseTitle ?? 'General Case',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_session.hearingDate != null) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 7.w, vertical: 2.5.h),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_rounded,
                          size: 11.sp, color: Colors.amber),
                      SizedBox(width: 4.w),
                      Text(
                        DateFormat('dd MMM').format(_session.hearingDate!),
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsList(
      List<CrossExamQuestion> allQuestions, bool isDark) {
    final questions = _filterOnlyKeyQuestions
        ? allQuestions.where((q) => q.isKeyQuestion).toList()
        : allQuestions;

    if (questions.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(32.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _filterOnlyKeyQuestions
                    ? Icons.stars_rounded
                    : Icons.rate_review_outlined,
                size: 48.sp,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
              ),
              SizedBox(height: 12.h),
              Text(
                _filterOnlyKeyQuestions
                    ? 'No Key / Trap Questions'
                    : 'No Questions Added Yet',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                _filterOnlyKeyQuestions
                    ? 'Mark questions with 🎯 to isolate killer points for quick courtroom reference.'
                    : 'Type a question in the bar below to start framing your examination sequence.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  color: isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      scrollController: _scrollController,
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
      itemCount: questions.length,
      onReorder: (oldIndex, newIndex) =>
          _handleReorder(questions, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final q = questions[index];
        final isExpanded = _expandedQuestionIds.contains(q.id);

        return Dismissible(
          key: ValueKey(q.id),
          background: Container(
            margin: EdgeInsets.only(bottom: 10.h),
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius: BorderRadius.circular(16.r),
            ),
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(left: 20.w),
            child: Row(
              children: [
                Icon(
                  q.isKeyQuestion ? Icons.star_border : Icons.stars_rounded,
                  color: Colors.white,
                ),
                SizedBox(width: 8.w),
                Text(
                  q.isKeyQuestion ? 'Unmark Key' : 'Mark Key 🎯',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            margin: EdgeInsets.only(bottom: 10.h),
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(16.r),
            ),
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: 20.w),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.delete_outline_rounded, color: Colors.white),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Toggle Key question
              await CrossExamRepository.updateQuestion(
                  q.id, {'is_key_question': !q.isKeyQuestion});
              ref.invalidate(crossExamQuestionsProvider(_session.id));
              return false;
            } else {
              // Delete
              await CrossExamRepository.deleteQuestion(q.id);
              ref.invalidate(crossExamQuestionsProvider(_session.id));
              ref.invalidate(crossExamSessionsProvider);
              return true;
            }
          },
          child: _buildQuestionCard(
            context,
            question: q,
            displayNumber: index + 1,
            isExpanded: isExpanded,
            isDark: isDark,
          ),
        );
      },
    );
  }

  Widget _buildQuestionCard(
    BuildContext context, {
    required CrossExamQuestion question,
    required int displayNumber,
    required bool isExpanded,
    required bool isDark,
  }) {
    final cat = question.category;

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161F30) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: question.isKeyQuestion
              ? Colors.amber.withValues(alpha: 0.8)
              : (isDark ? const Color(0xFF26334D) : const Color(0xFFE2E8F0)),
          width: question.isKeyQuestion ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsed Top Row / Header
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedQuestionIds.remove(question.id);
                } else {
                  _expandedQuestionIds.add(question.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(16.r),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10.w, 12.h, 12.w, 12.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reorder drag handle
                  Padding(
                    padding: EdgeInsets.only(top: 2.h, right: 4.w),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 18.sp,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                  // Auto-number Badge
                  Container(
                    width: 30.r,
                    height: 30.r,
                    decoration: BoxDecoration(
                      color: question.isKeyQuestion
                          ? Colors.amber.withValues(alpha: 0.15)
                          : AppTheme.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'Q$displayNumber',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w900,
                          color: question.isKeyQuestion
                              ? Colors.amber.shade800
                              : AppTheme.accent,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // Question content & meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.questionText,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            height: 1.3,
                          ),
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6.h),
                        Wrap(
                          spacing: 6.w,
                          runSpacing: 4.h,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Priority Dot
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(question.priority.emoji,
                                    style: TextStyle(fontSize: 10.sp)),
                                SizedBox(width: 3.w),
                                Text(
                                  question.priority.label,
                                  style: TextStyle(
                                    fontSize: 10.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            // Category Chip
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                '${cat.emoji} ${cat.label}',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                            if (question.isKeyQuestion)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  '🎯 Trap / Key',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            if (question.hasNotes && !isExpanded)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6.r),
                                ),
                                child: Text(
                                  '📝 Notes',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Expand Chevron
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                    size: 20.sp,
                  ),
                ],
              ),
            ),
          ),
          // Expanded Editor Section
          if (isExpanded)
            _buildExpandedEditor(context, question, isDark),
        ],
      ),
    );
  }

  Widget _buildExpandedEditor(
      BuildContext context, CrossExamQuestion question, bool isDark) {
    return _QuestionEditorWidget(
      question: question,
      isDark: isDark,
      onSave: (updates) async {
        await CrossExamRepository.updateQuestion(question.id, updates);
        ref.invalidate(crossExamQuestionsProvider(_session.id));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Question updated successfully'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      onDelete: () async {
        await CrossExamRepository.deleteQuestion(question.id);
        ref.invalidate(crossExamQuestionsProvider(_session.id));
        ref.invalidate(crossExamSessionsProvider);
      },
    );
  }

  Widget _buildQuickAddBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16.w,
        10.h,
        16.w,
        MediaQuery.of(context).viewInsets.bottom + 12.h,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF26334D) : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: TextField(
                controller: _quickAddController,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submitQuickAdd(),
                style: TextStyle(
                  fontSize: 13.5.sp,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Type question & tap add...',
                  hintStyle: TextStyle(
                    fontSize: 12.5.sp,
                    color: isDark
                        ? const Color(0xFF64748B)
                        : const Color(0xFF94A3B8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 12.h),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Send / Add Button
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: _isAdding
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded,
                      color: Colors.white),
              onPressed: _isAdding ? null : _submitQuickAdd,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitQuickAdd() async {
    final text = _quickAddController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isAdding = true);
    _quickAddController.clear();

    try {
      await CrossExamRepository.addQuestion(_session.id, text);
      ref.invalidate(crossExamQuestionsProvider(_session.id));
      ref.invalidate(crossExamSessionsProvider);

      // Auto scroll to bottom
      Future.delayed(const Duration(milliseconds: 250), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add question: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _handleReorder(
      List<CrossExamQuestion> currentList, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = currentList.removeAt(oldIndex);
    currentList.insert(newIndex, item);

    final orderedIds = currentList.map((q) => q.id).toList();
    await CrossExamRepository.reorderQuestions(orderedIds);
    ref.invalidate(crossExamQuestionsProvider(_session.id));
  }

  void _handleMenuAction(String action) {
    if (action == 'export_pdf') {
      _exportToPdf();
    } else if (action == 'edit_session') {
      _showEditSessionSheet();
    } else if (action == 'change_status') {
      _showChangeStatusDialog();
    } else if (action == 'delete_session') {
      _confirmDeleteSession();
    }
  }

  void _showChangeStatusDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Update Session Status'),
        children: SessionStatus.values.map((st) {
          final isCurrent = _session.status == st;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (isCurrent) return;
              try {
                await CrossExamRepository.updateSession(
                    _session.id, {'status': st.name});
                setState(() {
                  _session = _session.copyWith(status: st);
                });
                ref.invalidate(crossExamSessionsProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status: $e')),
                  );
                }
              }
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                children: [
                  Text(st.emoji, style: TextStyle(fontSize: 18.sp)),
                  SizedBox(width: 12.w),
                  Text(
                    st.label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight:
                          isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: isCurrent ? AppTheme.accent : null,
                    ),
                  ),
                  if (isCurrent) ...[
                    const Spacer(),
                    const Icon(Icons.check, color: AppTheme.accent, size: 18),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showEditSessionSheet() {
    final witnessCtrl = TextEditingController(text: _session.witnessName);
    final tagCtrl = TextEditingController(text: _session.witnessTag);
    DateTime? hearingDate = _session.hearingDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF0F172A)
                : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          padding: EdgeInsets.fromLTRB(
            20.w,
            16.h,
            20.w,
            MediaQuery.of(ctx).viewInsets.bottom + 24.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Witness Details',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: witnessCtrl,
                decoration: const InputDecoration(
                  labelText: 'Witness Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: tagCtrl,
                decoration: const InputDecoration(
                  labelText: 'Designation / Tag (e.g. PW1, DW2)',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: hearingDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) {
                    setModalState(() => hearingDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Hearing Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    hearingDate != null
                        ? DateFormat('dd MMM yyyy').format(hearingDate!)
                        : 'Not set',
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 46.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final updates = {
                      'witness_name': witnessCtrl.text.trim(),
                      'witness_tag': tagCtrl.text.trim(),
                      'hearing_date':
                          hearingDate?.toIso8601String().split('T').first,
                    };
                    await CrossExamRepository.updateSession(
                        _session.id, updates);
                    setState(() {
                      _session = CrossExamSession(
                        id: _session.id,
                        caseId: _session.caseId,
                        witnessId: _session.witnessId,
                        userId: _session.userId,
                        firmId: _session.firmId,
                        witnessName: witnessCtrl.text.trim(),
                        witnessTag: tagCtrl.text.trim(),
                        status: _session.status,
                        hearingDate: hearingDate,
                        notes: _session.notes,
                        caseTitle: _session.caseTitle,
                        questionCount: _session.questionCount,
                        createdAt: _session.createdAt,
                        updatedAt: DateTime.now(),
                      );
                    });
                    ref.invalidate(crossExamSessionsProvider);
                  },
                  child: const Text('Save Changes',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text(
          'Are you sure you want to delete this session for "${_session.witnessName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await CrossExamRepository.deleteSession(_session.id);
              ref.invalidate(crossExamSessionsProvider);
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf() async {
    final questions =
        await CrossExamRepository.fetchQuestions(_session.id);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CROSS-EXAMINATION PLAN',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.indigo900,
                    ),
                  ),
                  pw.Text(
                    'CONFIDENTIAL ADVOCATE WORK PRODUCT',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Text(
                DateFormat('dd MMM yyyy').format(DateTime.now()),
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.Divider(thickness: 1, color: PdfColors.indigo900),
          pw.SizedBox(height: 10),

          // Case & Witness Meta Box
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Text('Case: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Expanded(
                      child: pw.Text(_session.caseTitle ?? 'General Case'),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text('Witness: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${_session.witnessTag} - ${_session.witnessName}'),
                    pw.Spacer(),
                    pw.Text('Status: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(_session.status.label),
                  ],
                ),
                if (_session.hearingDate != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Text('Hearing Date: ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        DateFormat('dd MMM yyyy')
                            .format(_session.hearingDate!),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Section Title
          pw.Text(
            'EXAMINATION QUESTIONS (${questions.length})',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.indigo900,
            ),
          ),
          pw.SizedBox(height: 8),

          // Questions List
          ...questions.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final q = entry.value;

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: q.isKeyQuestion
                      ? PdfColors.amber700
                      : PdfColors.grey300,
                  width: q.isKeyQuestion ? 1.5 : 0.8,
                ),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Q$idx. ',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                          color: q.isKeyQuestion
                              ? PdfColors.amber900
                              : PdfColors.indigo900,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          q.questionText,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      pw.Text(
                        ' [${q.category.label} | ${q.priority.label}]',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  if (q.expectedAnswer != null &&
                      q.expectedAnswer!.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Expected Answer: ${q.expectedAnswer}',
                      style: const pw.TextStyle(
                          fontSize: 9.5, color: PdfColors.blueGrey800),
                    ),
                  ],
                  if (q.followUpIfYes != null &&
                      q.followUpIfYes!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'If Yes: ${q.followUpIfYes}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.green900),
                    ),
                  ],
                  if (q.followUpIfNo != null &&
                      q.followUpIfNo!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'If No: ${q.followUpIfNo}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.red900),
                    ),
                  ],
                  if (q.advocateNotes != null &&
                      q.advocateNotes!.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Notes: ${q.advocateNotes}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Cross_Exam_${_session.witnessTag}_${_session.witnessName}.pdf',
    );
  }
}

/// Expandable editor widget for a question.
class _QuestionEditorWidget extends StatefulWidget {
  final CrossExamQuestion question;
  final bool isDark;
  final ValueChanged<Map<String, dynamic>> onSave;
  final VoidCallback onDelete;

  const _QuestionEditorWidget({
    required this.question,
    required this.isDark,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_QuestionEditorWidget> createState() => _QuestionEditorWidgetState();
}

class _QuestionEditorWidgetState extends State<_QuestionEditorWidget> {
  late TextEditingController _textCtrl;
  late TextEditingController _expectedCtrl;
  late TextEditingController _ifYesCtrl;
  late TextEditingController _ifNoCtrl;
  late TextEditingController _notesCtrl;
  late QuestionCategory _category;
  late QuestionPriority _priority;
  late bool _isKey;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.question.questionText);
    _expectedCtrl =
        TextEditingController(text: widget.question.expectedAnswer ?? '');
    _ifYesCtrl =
        TextEditingController(text: widget.question.followUpIfYes ?? '');
    _ifNoCtrl =
        TextEditingController(text: widget.question.followUpIfNo ?? '');
    _notesCtrl =
        TextEditingController(text: widget.question.advocateNotes ?? '');
    _category = widget.question.category;
    _priority = widget.question.priority;
    _isKey = widget.question.isKeyQuestion;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _expectedCtrl.dispose();
    _ifYesCtrl.dispose();
    _ifNoCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: isDark ? const Color(0xFF26334D) : const Color(0xFFF1F5F9),
          ),
          SizedBox(height: 8.h),

          // Editable Question Text
          _buildField(
            controller: _textCtrl,
            label: 'Question Text',
            isDark: isDark,
            maxLines: 2,
          ),
          SizedBox(height: 10.h),

          // Expected Answer
          _buildField(
            controller: _expectedCtrl,
            label: 'Expected Witness Answer',
            hint: 'e.g. Likely to deny knowing the accused',
            isDark: isDark,
          ),
          SizedBox(height: 10.h),

          // Follow-ups Row
          Row(
            children: [
              Expanded(
                child: _buildField(
                  controller: _ifYesCtrl,
                  label: 'Follow-up (If Yes)',
                  hint: 'Confront with time / map',
                  isDark: isDark,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildField(
                  controller: _ifNoCtrl,
                  label: 'Follow-up (If No)',
                  hint: 'Show marked exhibit D-4',
                  isDark: isDark,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Advocate Notes
          _buildField(
            controller: _notesCtrl,
            label: 'Advocate Strategy Notes / Statutory Reference',
            hint: 'Sec 145 Evidence Act, FIR page 3 contradiction',
            isDark: isDark,
          ),
          SizedBox(height: 12.h),

          // Category Selector
          Text(
            'CATEGORY',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: QuestionCategory.values.map((cat) {
              final isSelected = _category == cat;
              return ChoiceChip(
                label: Text('${cat.emoji} ${cat.label}'),
                selected: isSelected,
                selectedColor: AppTheme.accent,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10.5.sp,
                ),
                onSelected: (val) {
                  if (val) setState(() => _category = cat);
                },
              );
            }).toList(),
          ),
          SizedBox(height: 12.h),

          // Priority Selector
          Text(
            'PRIORITY',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: QuestionPriority.values.map((p) {
              final isSelected = _priority == p;
              return ChoiceChip(
                label: Text('${p.emoji} ${p.label}'),
                selected: isSelected,
                selectedColor: AppTheme.accent,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : null,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 10.5.sp,
                ),
                onSelected: (val) {
                  if (val) setState(() => _priority = p);
                },
              );
            }).toList(),
          ),
          SizedBox(height: 10.h),

          // Key Question Switch
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _isKey,
            onChanged: (val) => setState(() => _isKey = val),
            title: Text(
              '🎯 Mark as Crucial / Trap Question',
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              'Highlights this question during rapid trial review',
              style: TextStyle(
                fontSize: 10.5.sp,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // Actions: Delete and Save
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete Question'),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Question?'),
                      content: const Text(
                          'Are you sure you want to remove this question?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            widget.onDelete();
                          },
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                icon: const Icon(Icons.save_rounded,
                    size: 16, color: Colors.white),
                label: const Text('Save Details',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  widget.onSave({
                    'question_text': _textCtrl.text.trim(),
                    'expected_answer': _expectedCtrl.text.trim().isEmpty
                        ? null
                        : _expectedCtrl.text.trim(),
                    'follow_up_if_yes': _ifYesCtrl.text.trim().isEmpty
                        ? null
                        : _ifYesCtrl.text.trim(),
                    'follow_up_if_no': _ifNoCtrl.text.trim().isEmpty
                        ? null
                        : _ifNoCtrl.text.trim(),
                    'advocate_notes': _notesCtrl.text.trim().isEmpty
                        ? null
                        : _notesCtrl.text.trim(),
                    'category': _category.dbValue,
                    'priority': _priority.name,
                    'is_key_question': _isKey,
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required bool isDark,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 12.5.sp,
        color: isDark ? Colors.white : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          fontSize: 11.5.sp,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
        hintStyle: TextStyle(
          fontSize: 11.5.sp,
          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }
}
