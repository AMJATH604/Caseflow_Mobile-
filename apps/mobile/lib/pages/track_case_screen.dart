import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/ecourt_parser_service.dart';

class TrackCaseScreen extends ConsumerStatefulWidget {
  final String? initialText;
  const TrackCaseScreen({super.key, this.initialText});

  @override
  ConsumerState<TrackCaseScreen> createState() => _TrackCaseScreenState();
}

class _TrackCaseScreenState extends ConsumerState<TrackCaseScreen> {
  final _textController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;
  final _fmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _textController.text = widget.initialText!;
      // Delaying the auto-search slightly so the UI can build first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trackCase();
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _trackCase() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(
        () =>
            _error =
                'Please paste your eCourts case details or enter a CNR number.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
    });

    try {
      final parsed = await EcourtParserService.parseEcourtText(text);
      if (parsed != null && parsed.isNotEmpty) {
        setState(() => _result = parsed);
      } else {
        setState(
          () =>
              _error =
                  'Could not parse case details. Please paste the full case status page from eCourts.',
        );
      }
    } catch (e) {
      setState(
        () =>
            _error =
                'Failed to parse case data. Please check your internet connection and try again.',
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Track My Case',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Paste your eCourts case details to see status, hearing history, and more.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color:
                      isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 20),

              // Input card
              _buildInputCard(isDark),

              const SizedBox(height: 16),

              // Error
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Results
              if (_result != null) ...[
                const SizedBox(height: 20),
                _buildStatusCard(isDark),
                const SizedBox(height: 14),
                _buildCaseDetailsCard(isDark),
                const SizedBox(height: 14),
                _buildPartyDetailsCard(isDark),
                if (_result!['hearing_history'] != null &&
                    (_result!['hearing_history'] as List).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildHearingTimeline(isDark),
                ],
                if (_result!['acts_sections'] != null &&
                    (_result!['acts_sections'] as List).isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _buildActsSections(isDark),
                ],
                const SizedBox(height: 20),
                _buildAdvocatePrompt(isDark),
              ],

              // Empty state
              if (_result == null && _error == null && !_isLoading) ...[
                const SizedBox(height: 40),
                _buildEmptyState(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Case Details',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Paste the full case status page content from the eCourts website or app:',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _textController,
            maxLines: 6,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp('')),
            ], // allow all
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText:
                  'Paste eCourts case status text here...\n\nExample: Copy everything from the eCourts case status page including case number, parties, hearing details.',
              hintStyle: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color:
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF10B981),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(14),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _trackCase,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Track Case',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
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

  Widget _buildStatusCard(bool isDark) {
    final status =
        (_result!['case_status'] ?? 'not_available').toString().toLowerCase();
    final isPending = status == 'pending';
    final isDisposed = status == 'disposed';

    final nextDate = _result!['next_hearing_date'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isPending
                  ? [const Color(0xFF065F46), const Color(0xFF10B981)]
                  : isDisposed
                  ? [const Color(0xFF991B1B), const Color(0xFFEF4444)]
                  : [const Color(0xFF1E3A5F), const Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isPending
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444))
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPending
                          ? Icons.schedule_rounded
                          : isDisposed
                          ? Icons.check_circle_rounded
                          : Icons.info_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextDate != null) ...[
            const SizedBox(height: 14),
            Text(
              'Next Hearing',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(nextDate.toString()),
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
          if (_result!['cnr_number'] != null) ...[
            const SizedBox(height: 10),
            Text(
              "CNR: ${_result!['cnr_number']}",
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCaseDetailsCard(bool isDark) {
    return _buildInfoCard(
      isDark,
      'Case Details',
      Icons.description_rounded,
      const Color(0xFF6366F1),
      [
        if (_result!['case_type'] != null)
          _infoRow('Case Type', _result!['case_type']),
        if (_result!['case_number'] != null)
          _infoRow('Case Number', _result!['case_number']),
        if (_result!['filing_number'] != null)
          _infoRow('Filing Number', _result!['filing_number']),
        if (_result!['filing_date'] != null)
          _infoRow('Filing Date', _formatDate(_result!['filing_date'])),
        if (_result!['court_name'] != null)
          _infoRow('Court', _result!['court_name']),
        if (_result!['judge_name'] != null)
          _infoRow('Judge', _result!['judge_name']),
        if (_result!['state'] != null || _result!['district'] != null)
          _infoRow(
            'Location',
            "${_result!['state'] ?? ''} / ${_result!['district'] ?? ''}",
          ),
      ],
    );
  }

  Widget _buildPartyDetailsCard(bool isDark) {
    return _buildInfoCard(
      isDark,
      'Parties',
      Icons.people_rounded,
      const Color(0xFF3B82F6),
      [
        if (_result!['petitioner_name'] != null)
          _infoRow('Petitioner', _result!['petitioner_name']),
        if (_result!['respondent_name'] != null)
          _infoRow('Respondent', _result!['respondent_name']),
        if (_result!['petitioner_advocate'] != null)
          _infoRow("Petitioner's Advocate", _result!['petitioner_advocate']),
        if (_result!['respondent_advocate'] != null)
          _infoRow("Respondent's Advocate", _result!['respondent_advocate']),
      ],
    );
  }

  Widget _buildInfoCard(
    bool isDark,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHearingTimeline(bool isDark) {
    final hearings = (_result!['hearing_history'] as List).take(10).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_rounded,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Hearing History',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '${hearings.length} hearings',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...hearings.asMap().entries.map((entry) {
            final i = entry.key;
            final h = entry.value as Map<String, dynamic>;
            final isLast = i == hearings.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline dot + line
                  SizedBox(
                    width: 24,
                    child: Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                i == 0
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF64748B),
                            border: Border.all(
                              color:
                                  i == 0
                                      ? const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.3)
                                      : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              color:
                                  isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(h['hearing_date']?.toString() ?? ''),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                            ),
                          ),
                          if (h['purpose'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              h['purpose'],
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                          if (h['business_done'] != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              h['business_done'],
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActsSections(bool isDark) {
    final acts = _result!['acts_sections'] as List;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.gavel_rounded,
                color: Color(0xFFD4AF37),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Acts & Sections',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                acts.map((a) {
                  final act = a as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      "${act['act_name'] ?? ''}${act['section'] != null ? ' - ${act['section']}' : ''}",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvocatePrompt(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need legal advice on your case?',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This is general information only. Please consult a qualified advocate for legal advice.',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => context.push('/advocate-directory'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'Find Advocate',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.search_rounded,
            size: 60,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          const SizedBox(height: 16),
          Text(
            'Paste your eCourts case details above\nto see case status and hearing history',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF94A3B8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to use:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                _stepItem('1', 'Visit ecourts.gov.in or eCourts app'),
                _stepItem(
                  '2',
                  'Search your case by CNR, case number, or party name',
                ),
                _stepItem('3', 'Copy the entire case status page content'),
                _stepItem('4', 'Paste it above and tap Track Case'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepItem(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                num,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF10B981),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return _fmt.format(dt);
    } catch (_) {
      return raw;
    }
  }
}
