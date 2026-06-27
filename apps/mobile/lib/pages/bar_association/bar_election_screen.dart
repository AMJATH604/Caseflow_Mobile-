import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import '../../services/repositories/bar_association_repository.dart';

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
            fontSize: 20,
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
              const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _C.violet.withValues(alpha: 0.1),
                    _C.pink.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.how_to_vote_rounded,
                size: 48,
                color: _C.violet,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Election',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no ongoing elections at this time.\nYou will be notified when elections are announced.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _C.textSecondary,
                height: 1.6,
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
          padding: const EdgeInsets.all(16),
          children: [
            _buildElectionHeader(election),
            const SizedBox(height: 16),
            _buildTimeline(election),
            const SizedBox(height: 24),

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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _C.violet.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.how_to_vote_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      election.title,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    if (election.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        election.description!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  election.statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.15 + (_pulseController.value * 0.1),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                days > 0 ? '${days}d ${hours}h left' : '${hours}h left',
                style: GoogleFonts.inter(
                  fontSize: 12,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
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
                      width: 32,
                      height: 32,
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
                    const SizedBox(height: 6),
                    Text(
                      phase['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 11,
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
                        fontSize: 10,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
                if (index < phases.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 28),
                      decoration: BoxDecoration(
                        gradient: isDone
                            ? const LinearGradient(
                                colors: [_C.success, _C.success])
                            : null,
                        color: isDone ? null : _C.border,
                        borderRadius: BorderRadius.circular(1),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _C.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.border),
            ),
            child: Column(
              children: [
                Icon(Icons.hourglass_empty_rounded, size: 40,
                    color: _C.textMuted),
                const SizedBox(height: 12),
                Text(
                  'Voting posts are being set up',
                  style: GoogleFonts.inter(
                    fontSize: 14,
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
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select one candidate for each post',
              style: GoogleFonts.inter(fontSize: 13, color: _C.textSecondary),
            ),
            const SizedBox(height: 16),
            ...posts.map((post) => _buildPostVoting(post)),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.how_to_vote_rounded, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Submit Vote (${_selectedVotes.length}/${posts.length})',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
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
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: _C.violet),
            ),
          );
        }
        final nominations = nomSnapshot.data!;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _C.violet.withValues(alpha: 0.06),
                      _C.pink.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _C.violet.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: _C.violet,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      post.postName,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.violet,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedVotes.containsKey(post.id))
                      Container(
                        width: 24,
                        height: 24,
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
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Animated Radio
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? _C.violet : _C.border,
                              width: 2,
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
                        const SizedBox(width: 14),
                        // Avatar
                        Container(
                          width: 44,
                          height: 44,
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
                                          fontSize: 16,
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
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        // Name
                        Expanded(
                          child: Text(
                            nom.nomineeName ?? 'Unknown',
                            style: GoogleFonts.inter(
                              fontSize: 15,
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
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No candidates yet',
                    style: GoogleFonts.inter(
                      fontSize: 13,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _C.success.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
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
          const SizedBox(height: 20),
          Text(
            'Vote Cast Successfully',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _C.success,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your vote has been recorded anonymously.\nResults will be published after voting ends.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _C.textSecondary,
              height: 1.6,
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
                const Text('🏆', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  'Election Results',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _C.violet.withValues(alpha: 0.06),
                      _C.pink.withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, size: 20,
                        color: _C.violet),
                    const SizedBox(width: 8),
                    Text(
                      post.postName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _C.violet,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$totalVotes votes',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Results
              Padding(
                padding: const EdgeInsets.all(16),
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
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          if (isWinner)
                            const Text('🏆', style: TextStyle(fontSize: 18))
                          else
                            SizedBox(
                              width: 18,
                              child: Text(
                                '#${index + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _C.textMuted,
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Container(
                            width: 36,
                            height: 36,
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
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                        fontSize: 14,
                                        fontWeight: isWinner
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: _C.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '$votes (${pct.toStringAsFixed(0)}%)',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
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
                                const SizedBox(height: 6),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: pct / 100),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, value, __) => ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
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
          const SizedBox(height: 16),
          Text(
            'Voting Not Yet Open',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _C.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Voting will begin on ${DateFormat('dd MMM yyyy').format(election.votingStart)}',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _C.textSecondary,
              height: 1.5,
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
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Confirm Your Vote',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Once submitted, your vote cannot be changed. Are you sure you want to proceed?',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _C.textSecondary,
            height: 1.5,
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
                borderRadius: BorderRadius.circular(10),
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
            borderRadius: BorderRadius.circular(10),
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
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
