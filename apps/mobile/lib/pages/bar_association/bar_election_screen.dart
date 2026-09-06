import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import '../../services/repositories/bar_association_repository.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Premium Color Palette
class _C {
  static const primary = Color(0xFF4F46E5);
  static const violet = Color(0xFF7C3AED);
  static const pink = Color(0xFFDB2777);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);
  static const surface = Color(0xFFF8FAFC);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
}

class BarElectionScreen extends ConsumerStatefulWidget {
  final String associationId;
  const BarElectionScreen({super.key, required this.associationId});

  @override
  ConsumerState<BarElectionScreen> createState() => _BarElectionScreenState();
}

class _BarElectionScreenState extends ConsumerState<BarElectionScreen>
    with SingleTickerProviderStateMixin {
  final Map<String, String> _selectedVotes = {};
  bool _submitting = false;
  bool _hasVoted = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final electionAsync = ref.watch(barElectionProvider(widget.associationId));
    final memberAsync = ref.watch(barMembershipProvider(widget.associationId));

    return Scaffold(
      backgroundColor: _C.surface,
      appBar: AppBar(
        title: Text(
          'Elections',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 20.sp,
            color: _C.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _C.textPrimary),
      ),
      body: electionAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _C.violet),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48,
                  color: _C.danger.withValues(alpha: 0.5)),
              SizedBox(height: 12.h),
              Text('Failed to load election',
                  style: GoogleFonts.inter(color: _C.textMuted)),
            ],
          ),
        ),
        data: (election) {
          if (election == null) return _buildNoElection();
          return memberAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: _C.violet),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (member) {
              if (member == null) {
                return const Center(child: Text('Membership not found'));
              }
              return _buildElectionContent(election, member);
            },
          );
        },
      ),
    );
  }

  // ── No Election ───────────────────────────────────────
  Widget _buildNoElection() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100.w,
              height: 100.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _C.violet.withValues(alpha: 0.1),
                    _C.pink.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(30.r),
              ),
              child: const Icon(
                Icons.how_to_vote_rounded,
                size: 48,
                color: _C.violet,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Active Election',
              style: GoogleFonts.inter(
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'There are no ongoing elections at this time.\nYou will be notified when elections are announced.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14.sp,
                color: _C.textSecondary,
                height: 1.6.h,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Election Content ──────────────────────────────────
  Widget _buildElectionContent(BarElection election, BarMember member) {
    return FutureBuilder<bool>(
      future: BarAssociationRepository.hasVoted(election.id, member.id),
      builder: (context, snapshot) {
        _hasVoted = snapshot.data ?? false;

        return ListView(
          padding: EdgeInsets.all(16.r),
          children: [
            _buildElectionHeader(election),
            SizedBox(height: 16.h),
            _buildTimeline(election),
            SizedBox(height: 24.h),

            if (election.isVotingOpen && !_hasVoted)
              _buildVotingSection(election, member)
            else if (_hasVoted)
              _buildAlreadyVoted()
            else if (election.isCompleted)
              _buildResultsSection(election)
            else
              _buildWaitingSection(election),
          ],
        );
      },
    );
  }

  // ── Election Header (Premium Gradient) ────────────────
  Widget _buildElectionHeader(BarElection election) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.violet, _C.pink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: _C.violet.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.h,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: const Icon(
                  Icons.how_to_vote_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      election.title,
                      style: GoogleFonts.inter(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (election.description != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        election.description!,
                        style: GoogleFonts.inter(
                          fontSize: 13.sp,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  election.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              if (election.isVotingOpen) ...[
                const Spacer(),
                _buildCountdown(election.votingEnd),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Countdown Timer ───────────────────────────────────
  Widget _buildCountdown(DateTime end) {
    final remaining = end.difference(DateTime.now());
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.15 + (_pulseController.value * 0.1),
            ),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, size: 14, color: Colors.white),
              SizedBox(width: 6.w),
              Text(
                days > 0 ? '${days}d ${hours}h left' : '${hours}h left',
                style: GoogleFonts.inter(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Timeline ──────────────────────────────────────────
  Widget _buildTimeline(BarElection election) {
    final phases = [
      {
        'label': 'Setup',
        'date': election.nominationStart,
        'active': election.status == 'draft',
        'done': ['nominations', 'voting', 'completed'].contains(election.status),
      },
      {
        'label': 'Voting',
        'date': election.votingStart,
        'active': election.status == 'voting',
        'done': election.status == 'completed',
      },
      {
        'label': 'Results',
        'date': election.votingEnd,
        'active': false,
        'done': election.isCompleted && election.resultsPublished,
      },
    ];

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: phases.asMap().entries.map((entry) {
          final index = entry.key;
          final phase = entry.value;
          final isActive = phase['active'] as bool;
          final isDone = phase['done'] as bool;

          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 32.w,
                      height: 32.h,
                      decoration: BoxDecoration(
                        gradient: (isDone || isActive)
                            ? LinearGradient(
                                colors: isDone
                                    ? [_C.success, const Color(0xFF059669)]
                                    : [_C.violet, _C.pink],
                              )
                            : null,
                        color: (isDone || isActive) ? null : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                        boxShadow: (isDone || isActive)
                            ? [
                                BoxShadow(
                                  color: (isDone ? _C.success : _C.violet)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isDone
                            ? Icons.check_rounded
                            : isActive
                                ? Icons.radio_button_checked
                                : Icons.circle_outlined,
                        color: (isDone || isActive)
                            ? Colors.white
                            : _C.textMuted,
                        size: 18,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      phase['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 11.sp,
                        fontWeight: (isDone || isActive)
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: (isDone || isActive)
                            ? _C.textPrimary
                            : _C.textMuted,
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM').format(phase['date'] as DateTime),
                      style: GoogleFonts.inter(
                        fontSize: 10.sp,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
                if (index < phases.length - 1)
                  Expanded(
                    child: Container(
                      height: 2.h,
                      margin: EdgeInsets.only(bottom: 28.h),
                      decoration: BoxDecoration(
                        gradient: isDone
                            ? const LinearGradient(
                                colors: [_C.success, _C.success])
                            : null,
                        color: isDone ? null : _C.border,
                        borderRadius: BorderRadius.circular(1.r),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Voting Section ────────────────────────────────────
  Widget _buildVotingSection(BarElection election, BarMember member) {
    return FutureBuilder<List<BarElectionPost>>(
      future: BarAssociationRepository.getElectionPosts(election.id),
      builder: (context, postsSnapshot) {
        if (!postsSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _C.violet),
          );
        }
        final posts = postsSnapshot.data!;

        if (posts.isEmpty) {
          return Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 40,
                    color: _C.textMuted),
                SizedBox(height: 12.h),
                Text(
                  'Voting posts are being set up',
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: _C.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cast Your Vote',
              style: GoogleFonts.inter(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Select one candidate for each post',
              style: GoogleFonts.inter(fontSize: 13.sp, color: _C.textSecondary),
            ),
            SizedBox(height: 16.h),
            ...posts.map((post) => _buildPostVoting(post)),
            SizedBox(height: 24.h),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: ElevatedButton(
                onPressed:
                    (_selectedVotes.length == posts.length && !_submitting)
                        ? () => _submitVotes(election, member)
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.violet,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.how_to_vote_rounded, size: 20),
                          SizedBox(width: 10.w),
                          Text(
                            'Submit Vote (${_selectedVotes.length}/${posts.length})',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16.sp,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 32.h),
          ],
        );
      },
    );
  }

  Widget _buildPostVoting(BarElectionPost post) {
    return FutureBuilder<List<BarNomination>>(
      future: BarAssociationRepository.getNominations(post.id),
      builder: (context, nomSnapshot) {
        if (!nomSnapshot.hasData) {
          return Padding(
            padding: EdgeInsets.all(16.r),
            child: Center(
              child: CircularProgressIndicator(color: _C.violet),
            ),
          );
        }
        final nominations = nomSnapshot.data!;

        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _C.violet.withValues(alpha: 0.06),
                      _C.pink.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32.w,
                      height: 32.h,
                      decoration: BoxDecoration(
                        color: _C.violet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: _C.violet,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      post.postName,
                      style: GoogleFonts.inter(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: _C.violet,
                      ),
                    ),
                    Spacer(),
                    if (_selectedVotes.containsKey(post.id))
                      Container(
                        width: 24.w,
                        height: 24.h,
                        decoration: const BoxDecoration(
                          color: _C.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              // Candidates
              ...nominations.map((nom) {
                final isSelected = _selectedVotes[post.id] == nom.id;
                return InkWell(
                  onTap: () => setState(() => _selectedVotes[post.id] = nom.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _C.violet.withValues(alpha: 0.04)
                          : null,
                      border: Border(
                        bottom: BorderSide(
                          color: _C.border.withValues(alpha: 0.5),
                          width: 1.w,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Animated Radio
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24.w,
                          height: 24.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? _C.violet : _C.border,
                              width: 2.w,
                            ),
                            color: isSelected ? _C.violet : Colors.transparent,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _C.violet.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14,
                                  color: Colors.white)
                              : null,
                        ),
                        SizedBox(width: 14.w),
                        // Avatar
                        Container(
                          width: 44.w,
                          height: 44.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isSelected
                                  ? [_C.violet, _C.pink]
                                  : [const Color(0xFFE2E8F0), const Color(0xFFF1F5F9)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: nom.photoUrl != null
                              ? ClipOval(
                                  child: Image.network(
                                    nom.photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        (nom.nomineeName ?? 'U')[0].toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? Colors.white
                                              : _C.textSecondary,
                                          fontSize: 16.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    (nom.nomineeName ?? 'U')[0].toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : _C.textSecondary,
                                      fontSize: 16.sp,
                                    ),
                                  ),
                                ),
                        ),
                        SizedBox(width: 14.w),
                        // Name
                        Expanded(
                          child: Text(
                            nom.nomineeName ?? 'Unknown',
                            style: GoogleFonts.inter(
                              fontSize: 15.sp,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _C.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (nominations.isEmpty)
                Padding(
                  padding: EdgeInsets.all(20.r),
                  child: Text(
                    'No candidates yet',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      color: _C.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Already Voted ─────────────────────────────────────
  Widget _buildAlreadyVoted() {
    return Container(
      decoration: BoxDecoration(
        color: _C.success.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: _C.success.withValues(alpha: 0.15),
        ),
      ),
      padding: EdgeInsets.all(32.r),
      child: Column(
        children: [
          Container(
            width: 72.w,
            height: 72.h,
            decoration: BoxDecoration(
              color: _C.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: 40,
              color: _C.success,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Vote Cast Successfully',
            style: GoogleFonts.inter(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: _C.success,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your vote has been recorded anonymously.\nResults will be published after voting ends.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14.sp,
              color: _C.textSecondary,
              height: 1.6.h,
            ),
          ),
        ],
      ),
    );
  }

  // ── Results Section ───────────────────────────────────
  Widget _buildResultsSection(BarElection election) {
    return FutureBuilder<List<BarElectionPost>>(
      future: BarAssociationRepository.getElectionPosts(election.id),
      builder: (context, postsSnapshot) {
        if (!postsSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _C.violet),
          );
        }
        final posts = postsSnapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('🏆', style: TextStyle(fontSize: 22.sp)),
                SizedBox(width: 8.w),
                Text(
                  'Election Results',
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ...posts.map((post) => _buildPostResult(post)),
          ],
        );
      },
    );
  }

  Widget _buildPostResult(BarElectionPost post) {
    return FutureBuilder<List<BarNomination>>(
      future: BarAssociationRepository.getNominationsWithVotes(post.id),
      builder: (context, nomSnapshot) {
        if (!nomSnapshot.hasData) {
          return const SizedBox.shrink();
        }
        final nominations = nomSnapshot.data!;
        final totalVotes = nominations.fold<int>(
          0, (s, n) => s + (n.voteCount ?? 0));
        final sorted = [...nominations]
          ..sort((a, b) => (b.voteCount ?? 0).compareTo(a.voteCount ?? 0));

        return Container(
          margin: EdgeInsets.only(bottom: 16.h),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _C.violet.withValues(alpha: 0.06),
                      _C.pink.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16.r),
                    topRight: Radius.circular(16.r),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 20,
                        color: _C.violet),
                    SizedBox(width: 8.w),
                    Text(
                      post.postName,
                      style: GoogleFonts.inter(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: _C.violet,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '$totalVotes votes',
                      style: GoogleFonts.inter(
                        fontSize: 12.sp,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Results
              Padding(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  children: sorted.asMap().entries.map((entry) {
                    final index = entry.key;
                    final nom = entry.value;
                    final votes = nom.voteCount ?? 0;
                    final pct = totalVotes > 0
                        ? (votes / totalVotes * 100)
                        : 0.0;
                    final isWinner = index == 0 && totalVotes > 0;

                    return Padding(
                      padding: EdgeInsets.only(bottom: 12.h),
                      child: Row(
                        children: [
                          if (isWinner)
                            Text('🏆', style: TextStyle(fontSize: 18.sp))
                          else
                            SizedBox(
                              width: 18.w,
                              child: Text(
                                '#${index + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _C.textMuted,
                                ),
                              ),
                            ),
                          SizedBox(width: 10.w),
                          Container(
                            width: 36.w,
                            height: 36.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isWinner
                                    ? [_C.violet, _C.pink]
                                    : [const Color(0xFFE2E8F0), const Color(0xFFF1F5F9)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                (nom.nomineeName ?? 'U')[0].toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: isWinner
                                      ? Colors.white
                                      : _C.textSecondary,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      nom.nomineeName ?? 'Unknown',
                                      style: GoogleFonts.inter(
                                        fontSize: 14.sp,
                                        fontWeight: isWinner
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _C.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '$votes (${pct.toStringAsFixed(0)}%)',
                                      style: GoogleFonts.inter(
                                        fontSize: 13.sp,
                                        fontWeight: isWinner
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isWinner
                                            ? _C.success
                                            : _C.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6.h),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: pct / 100),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, value, __) => ClipRRect(
                                    borderRadius: BorderRadius.circular(4.r),
                                    child: LinearProgressIndicator(
                                      value: value,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      valueColor: AlwaysStoppedAnimation(
                                        isWinner ? _C.success : _C.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Waiting Section ───────────────────────────────────
  Widget _buildWaitingSection(BarElection election) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _C.border),
      ),
      padding: EdgeInsets.all(32.r),
      child: Column(
        children: [
          Container(
            width: 64.w,
            height: 64.h,
            decoration: BoxDecoration(
              color: _C.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              size: 28,
              color: _C.primary.withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Voting Not Yet Open',
            style: GoogleFonts.inter(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Voting will begin on ${DateFormat('dd MMM yyyy').format(election.votingStart)}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.sp,
              color: _C.textSecondary,
              height: 1.5.h,
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit Votes ──────────────────────────────────────
  Future<void> _submitVotes(BarElection election, BarMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Text(
          'Confirm Your Vote',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Once submitted, your vote cannot be changed. Are you sure you want to proceed?',
          style: GoogleFonts.inter(
            fontSize: 14.sp,
            color: _C.textSecondary,
            height: 1.5.h,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: _C.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.violet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'Submit Vote',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _submitting = true);
    try {
      await BarAssociationRepository.castVote(
        electionId: election.id,
        memberId: member.id,
        votes: _selectedVotes,
      );
      if (!mounted) return;
      setState(() => _hasVoted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Vote submitted successfully!',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: _C.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ $e'),
          backgroundColor: _C.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
