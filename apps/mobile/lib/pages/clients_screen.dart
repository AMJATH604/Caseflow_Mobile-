import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/providers.dart';
import '../services/supabase_service.dart';
import '../components/dialogs/add_client_dialog.dart';
import '../theme/app_theme.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomHeader(isMobile),
            const SizedBox(height: 16),
            _buildSearch(isMobile),
            const SizedBox(height: 16),
            Expanded(
              child: clientsAsync.when(
                data: (clients) => _buildClientsList(isMobile, clients),
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text("Connection Error", style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text("$err", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
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
      floatingActionButton: isMobile 
          ? FloatingActionButton(
              onPressed: () => _showAddClientDialog(context),
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.black,
              child: const Icon(Icons.person_add_rounded, size: 28),
            )
          : null,
    );
  }

  Widget _buildCustomHeader(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Relationship Nodes",
                style: GoogleFonts.inter(
                  fontSize: 28, 
                  fontWeight: FontWeight.w900, 
                  color: const Color(0xFF1E293B),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Access controlled professional directory",
                style: TextStyle(
                  color: const Color(0xFF94A3B8), 
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!isMobile)
            ElevatedButton.icon(
              onPressed: () => _showAddClientDialog(context),
              icon: const Icon(Icons.person_add_rounded, size: 20),
              label: const Text("Enroll Node", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
          decoration: InputDecoration(
            hintText: "Search access controlled nodes...",
            hintStyle: TextStyle(color: const Color(0xFFCBD5E1)),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: const Color(0xFF94A3B8)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildClientsList(bool isMobile, List<dynamic> clients) {
    final filtered = clients.where((c) {
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || (c.phone ?? "").contains(q) || (c.email ?? "").toLowerCase().contains(q);
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text("No clients found."));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final c = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  c.name[0].toUpperCase(), 
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w900, fontSize: 16)
                ),
              ),
            ),
            title: Text(
              c.name, 
              style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B), fontSize: 15, letterSpacing: -0.5)
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  c.phone ?? c.email ?? (c.firmId != null ? "Firm Shared Client" : "Private Profile"), 
                  style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500)
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      "MEMBER SINCE ${DateFormat('MMM yyyy').format(c.createdAt).toUpperCase()}",
                      style: TextStyle(fontSize: 8, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.phone != null) 
                  _buildActionIcon(Icons.phone_rounded, const Color(0xFF64748B), () {}),
                const SizedBox(width: 8),
                _buildActionIcon(Icons.delete_outline_rounded, Colors.redAccent.withValues(alpha: 0.6), () => _deleteClient(c.id)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _showAddClientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddClientDialog(),
    );
  }

  void _deleteClient(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Client?"),
        content: const Text("This will also delete all cases associated with this client."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.deleteClient(id);
      ref.invalidate(clientsProvider);
    }
  }
}
