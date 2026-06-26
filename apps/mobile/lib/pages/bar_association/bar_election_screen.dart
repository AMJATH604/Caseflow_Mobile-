import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/bar_association_models.dart';
import '../../services/providers.dart';
import '../../services/repositories/bar_association_repository.dart';
import '../../theme/app_theme.dart';

class BarElectionScreen extends ConsumerStatefulWidget {
  final String associationId;
  const BarElectionScreen({super.key, required this.associationId});

  @override
  ConsumerState<BarElectionScreen> createState() => _BarElectionScreenState();
}

class _BarElectionScreenState extends ConsumerState<BarElectionScreen> {
  // Map<postId, selectedNominationId>
  final Map<String, String> _selectedVotes = {};
  bool _submitting = false;
  bool _hasVoted = false;

  @override
  Widget build(BuildContext context) {
    final electionAsync =
        ref.watch(barElectionProvider(widget.associationId));
    final memberAsync =
        ref.watch(barMembershipProvider(widget.associationId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Elections',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: electionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text('Failed to load election', style: GoogleFonts.inter()),
            ],
          ),
        ),
        data: (election) {
          if (election == null) {
            return _buildNoElection();
          }
          return memberAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
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
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.how_to_vote_rounded,
                size: 48,
                color: Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Election',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no ongoing elections at this time.\nYou will be notified when elections are announced.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildElectionContent(BarElection election, BarMember member) {
    return FutureBuilder<bool>(
      future: BarAssociationRepository.hasVoted(election.id, member.id),
      builder: (context, snapshot) {
        _hasVoted = snapshot.data ?? false;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Election Header ──
            _buildElectionHeader(election),
            const SizedBox(height: 16),

            // ── Timeline Progress ──
            _buildTimeline(election),
            const SizedBox(height: 24),

            // ── Voting / Results ──
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

  // ── Election Header ───────────────────────────────────
  Widget _buildElectionHeader(BarElection election) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🗳️', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  election.title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (election.description != null) ...[
            const SizedBox(height: 8),
            Text(
              election.description!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
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
        ],
      ),
    );
  }

  // ── Timeline ──────────────────────────────────────────
  Widget _buildTimeline(BarElection election) {
    final phases = [
      {
        'label': 'Nominations',
        'date': election.nominationStart,
        'active': election.status == 'nominations',
        'done': ['voting', 'completed'].contains(election.status),
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
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(20),
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
                        color: isDone
                            ? const Color(0xFF10B981)
                            : isActive
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDone
                            ? Icons.check_rounded
                            : isActive
                                ? Icons.radio_button_checked
                                : Icons.circle_outlined,
                        color: (isDone || isActive)
                            ? Colors.white
                            : const Color(0xFF94A3B8),
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
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM').format(phase['date'] as DateTime),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                if (index < phases.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 28),
                      color: isDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE2E8F0),
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
          return const Center(child: CircularProgressIndicator());
        }

        final posts = postsSnapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cast Your Vote',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select one candidate for each post',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),

            ...posts.map((post) => _buildPostVoting(post)),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: (_selectedVotes.length == posts.length && !_submitting)
                    ? () => _submitVotes(election, member)
                    : null,
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.how_to_vote_rounded),
                label: Text(
                  _submitting
                      ? 'Submitting Vote...'
                      : 'Submit Vote (${_selectedVotes.length}/${posts.length})',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final nominations = nomSnapshot.data!;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post name header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Text(
                  post.postName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ),
              // Candidates
              ...nominations.map((nom) {
                final isSelected = _selectedVotes[post.id] == nom.id;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedVotes[post.id] = nom.id;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.05)
                          : null,
                      border: Border(
                        bottom: BorderSide(
                          color: const Color(0xFFF1F5F9),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Radio
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFFCBD5E1),
                              width: 2,
                            ),
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        // Avatar
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFF1F5F9),
                          backgroundImage: nom.photoUrl != null
                              ? NetworkImage(nom.photoUrl!)
                              : null,
                          child: nom.photoUrl == null
                              ? Text(
                                  (nom.nomineeName ?? 'U')[0].toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF475569),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nom.nomineeName ?? 'Unknown',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              if (nom.proposerName != null)
                                Text(
                                  'Proposed by: ${nom.proposerName}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
        color: const Color(0xFF10B981).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 64,
            color: Color(0xFF10B981),
          ),
          const SizedBox(height: 16),
          Text(
            'Vote Cast Successfully ✅',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your vote has been recorded anonymously.\nResults will be published after voting ends.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.5,
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
          return const Center(child: CircularProgressIndicator());
        }

        final posts = postsSnapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Election Results',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            ...posts.map((post) => _buildPostResults(post)),
          ],
        );
      },
    );
  }

  Widget _buildPostResults(BarElectionPost post) {
    return FutureBuilder<Map<String, int>>(
      future: BarAssociationRepository.getVoteCounts(post.id),
      builder: (context, countsSnapshot) {
        return FutureBuilder<List<BarNomination>>(
          future: BarAssociationRepository.getNominations(post.id),
          builder: (context, nomsSnapshot) {
            if (!countsSnapshot.hasData || !nomsSnapshot.hasData) {
              return const SizedBox.shrink();
            }
            final counts = countsSnapshot.data!;
            final nominations = nomsSnapshot.data!;
            final totalVotes =
                counts.values.fold<int>(0, (sum, c) => sum + c);

            // Sort by vote count
            nominations.sort((a, b) {
              final aCount = counts[a.id] ?? 0;
              final bCount = counts[b.id] ?? 0;
              return bCount.compareTo(aCount);
            });

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          post.postName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C3AED),
                          ),
                        ),
                        Text(
                          '$totalVotes votes',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...nominations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final nom = entry.value;
                    final voteCount = counts[nom.id] ?? 0;
                    final percentage =
                        totalVotes > 0 ? (voteCount / totalVotes) : 0.0;
                    final isWinner = index == 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          if (isWinner)
                            const Text('🏆', style: TextStyle(fontSize: 20))
                          else
                            const SizedBox(width: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nom.nomineeName ?? 'Unknown',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: isWinner
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    valueColor: AlwaysStoppedAnimation(
                                      isWinner
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$voteCount',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isWinner
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Waiting Section ───────────────────────────────────
  Widget _buildWaitingSection(BarElection election) {
    return Container(
      decoration: AppTheme.cardDecoration(),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 48,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            election.isNominationOpen
                ? 'Nominations are open'
                : 'Voting opens on ${DateFormat('dd/MM/yyyy').format(election.votingStart)}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Submit Votes ──────────────────────────────────────
  Future<void> _submitVotes(BarElection election, BarMember member) async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Your Vote',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Your vote is anonymous and cannot be changed after submission.\n\nAre you sure you want to submit?',
          style: GoogleFonts.inter(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Submit Vote'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _submitting = true);

    try {
      await BarAssociationRepository.castVotes(
        electionId: election.id,
        memberId: member.id,
        votes: _selectedVotes,
      );

      setState(() {
        _hasVoted = true;
        _submitting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Vote cast successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to cast vote: $e')),
        );
      }
    }
  }
}
