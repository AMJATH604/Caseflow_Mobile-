import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../components/dialogs/add_client_dialog.dart';
import '../components/dialogs/client_detail_sheet.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _searchQuery = "";

  // Generate consistent gradient color from name
  Color _avatarColor(String name) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF0EA5E9),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomHeader(isMobile, isDark),
            const SizedBox(height: 16),
            _buildSearch(isDark),
            const SizedBox(height: 16),
            Expanded(
              child: clientsAsync.when(
                data: (clients) => _buildClientsList(isMobile, isDark, clients),
                loading:
                    () => const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    ),
                error:
                    (err, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Connection Error",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "$err",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(clientsProvider),
                              child: const Text("Retry Connection"),
                            ),
                          ],
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          isMobile
              ? FloatingActionButton(
                onPressed: () => _showAddClientDialog(context),
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                elevation: 6,
                child: const Icon(Icons.person_add_rounded, size: 24),
              )
              : null,
    );
  }

  Widget _buildCustomHeader(bool isMobile, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Client Directory",
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Manage your professional relationships",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          if (!isMobile)
            ElevatedButton.icon(
              onPressed: () => _showAddClientDialog(context),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: Text(
                "Add Client",
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2030) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: "Search clients by name, phone, or email...",
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFFCBD5E1),
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildClientsList(
    bool isMobile,
    bool isDark,
    List<ClientModel> clients,
  ) {
    final filtered =
        clients.where((c) {
          final q = _searchQuery.toLowerCase();
          return c.name.toLowerCase().contains(q) ||
              (c.phone ?? "").contains(q) ||
              (c.email ?? "").toLowerCase().contains(q);
        }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? "No clients yet" : "No clients found",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isEmpty
                  ? "Add your first client to get started"
                  : "Try a different search term",
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    // Stats bar
    final activeCount = filtered.where((c) => c.hasActiveCases).length;

    return Column(
      children: [
        // Stats Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildQuickStat(
                "Total",
                filtered.length,
                const Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              _buildQuickStat("Active", activeCount, const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildQuickStat(
                "Inactive",
                filtered.length - activeCount,
                const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Client Cards List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final c = filtered[index];
              return _buildClientCard(c, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Text(
              "$value",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha: 0.7),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard(ClientModel c, bool isDark) {
    final color = _avatarColor(c.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => ClientDetailSheet.show(context, c),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2030) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Gradient Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    c.name[0].toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Client Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                              fontSize: 15,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status dot
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color:
                                c.hasActiveCases
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (c.phone != null && c.phone!.isNotEmpty)
                          Expanded(
                            child: Text(
                              c.phone!,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else if (c.email != null && c.email!.isNotEmpty)
                          Expanded(
                            child: Text(
                              c.email!,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        else
                          Expanded(
                            child: Text(
                              "No contact info",
                              style: GoogleFonts.inter(
                                color: const Color(0xFFCBD5E1),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        // Case count badge
                        if (c.caseCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${c.caseCount} ${c.caseCount == 1 ? 'Case' : 'Cases'}",
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Since ${DateFormat('MMM yyyy').format(c.createdAt)}",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFFCBD5E1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Actions
              Column(
                children: [
                  _buildActionIcon(
                    Icons.open_in_new_rounded,
                    const Color(0xFF64748B),
                    () {
                      ClientDetailSheet.show(context, c);
                    },
                  ),
                  const SizedBox(height: 6),
                  _buildActionIcon(
                    Icons.delete_outline_rounded,
                    Colors.redAccent.withValues(alpha: 0.5),
                    () => _deleteClient(c),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showAddClientDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const AddClientDialog());
  }

  void _deleteClient(ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text("Delete Client?"),
              ],
            ),
            content: Text(
              "This will permanently remove ${client.name} and unlink all associated cases.",
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  "Cancel",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  "Delete",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await SupabaseService.deleteClient(client.id);
      ref.invalidate(clientsProvider);
    }
  }
}
