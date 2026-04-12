import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/collaborator_service.dart';
import '../theme/app_theme.dart';

class CollaboratorInvitationsScreen extends StatefulWidget {
  const CollaboratorInvitationsScreen({super.key});

  @override
  State<CollaboratorInvitationsScreen> createState() => _CollaboratorInvitationsScreenState();
}

class _CollaboratorInvitationsScreenState extends State<CollaboratorInvitationsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _invitations = [];

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);
    try {
      final invites = await CollaboratorService.fetchMyInvitations();
      setState(() {
        _invitations = invites;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading invitations: $e")));
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(String id, String status) async {
    try {
      await CollaboratorService.respondToInvitation(id, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'accepted' ? "Invitation Accepted" : "Invitation Rejected"),
            backgroundColor: status == 'accepted' ? AppTheme.success : AppTheme.darkBorder,
          ),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryLight,
      appBar: AppBar(
        title: Text("Case Invitations", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)),
        backgroundColor: AppTheme.darkCard,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _invitations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _invitations.length,
                  itemBuilder: (context, index) {
                    final invite = _invitations[index];
                    final caseInfo = invite['cases'];
                    final inviter = invite['profiles'] != null ? invite['profiles']['full_name'] : "A Colleague";
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.darkBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.folder_shared_rounded, color: AppTheme.accent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      caseInfo?['case_title'] ?? "Untitled Case",
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B)),
                                    ),
                                    Text(
                                      "Invited by $inviter",
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _respond(invite['id'], 'rejected'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    foregroundColor: const Color(0xFF64748B),
                                  ),
                                  child: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _respond(invite['id'], 'accepted'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accent,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                  ),
                                  child: const Text("ACCEPT", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mail_outline_rounded, size: 64, color: const Color(0xFFE2E8F0)),
          const SizedBox(height: 16),
          Text(
            "No Pending Invitations",
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          const Text(
            "When someone shares a case with you, it will appear here.",
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
