import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../models/geo_data.dart';
import '../../components/profile_avatar.dart';

// Provides the list of advocates based on current filters
final advocateSearchProvider = FutureProvider.family<
  List<Map<String, dynamic>>,
  String
>((ref, filterKey) async {
  try {
    final parts = filterKey.split('|');
    final state = parts[0] == 'All' ? null : parts[0];
    final district = parts[1] == 'All' ? null : parts[1];
    final searchQuery = parts[2];

    var query = Supabase.instance.client
        .from('profiles')
        .select(
          'id, full_name, email, mobile_number, practice_state, practice_district, office_address, registration_number, avatar_url',
        )
        .eq('is_public_directory_enabled', true);

    if (state != null && state.isNotEmpty) {
      query = query.eq('practice_state', state);
    }

    if (district != null && district.isNotEmpty) {
      query = query.eq('practice_district', district);
    }

    if (searchQuery.isNotEmpty) {
      query = query.ilike('full_name', '%$searchQuery%');
    }

    final response = await query
        .order('full_name')
        .timeout(
          const Duration(seconds: 15),
          onTimeout:
              () =>
                  throw 'Connection Timeout: The database is taking too long to respond. Please check your RLS policies or internet.',
        );

    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    debugPrint('Advocate Search Error: $e');
    rethrow;
  }
});

class AdvocateDirectoryScreen extends ConsumerStatefulWidget {
  const AdvocateDirectoryScreen({super.key});

  @override
  ConsumerState<AdvocateDirectoryScreen> createState() =>
      _AdvocateDirectoryScreenState();
}

class _AdvocateDirectoryScreenState
    extends ConsumerState<AdvocateDirectoryScreen> {
  String _searchQuery = '';
  String? _selectedState = 'All';
  String? _selectedDistrict = 'All';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    _channel =
        Supabase.instance.client
            .channel('public:profiles')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'profiles',
              callback: (payload) {
                final filterKey =
                    '$_selectedState|$_selectedDistrict|$_searchQuery';
                ref.invalidate(advocateSearchProvider(filterKey));
              },
            )
            .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filterKey = '$_selectedState|$_selectedDistrict|$_searchQuery';
    final advocatesAsync = ref.watch(advocateSearchProvider(filterKey));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.contact_page_rounded,
                color: AppTheme.accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Advocate Directory',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Find peers across India',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterHeader(isDark),
          Expanded(
            child: advocatesAsync.when(
              data: (advocates) {
                if (advocates.isEmpty) {
                  return _buildEmptyState(isDark);
                }
                return RefreshIndicator(
                  onRefresh:
                      () async =>
                          ref.invalidate(advocateSearchProvider(filterKey)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: advocates.length + 1, // +1 for count header
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "${advocates.length} Advocate${advocates.length == 1 ? '' : 's'}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _buildAdvocateCard(advocates[index - 1], isDark);
                    },
                  ),
                );
              },
              loading:
                  () => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.accent),
                        const SizedBox(height: 16),
                        Text(
                          'Loading directory...',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              error: (e, st) => _buildErrorState(e, filterKey, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors:
              isDark
                  ? [const Color(0xFF141B3D), const Color(0xFF0A0E27)]
                  : [const Color(0xFFF0F4FF), Colors.white],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        children: [
          // ─── Search Bar ──
          Container(
            decoration: BoxDecoration(
              color:
                  isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow:
                  !isDark
                      ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Advocate Name...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.accent,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 12),

          // ─── Filter Chips ──
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  label: 'State',
                  value: _selectedState,
                  items: ['All', ...stateDistricts.keys],
                  isDark: isDark,
                  onChanged: (val) {
                    setState(() {
                      _selectedState = val;
                      _selectedDistrict = 'All';
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterDropdown(
                  label: 'District',
                  value: _selectedDistrict,
                  items: [
                    'All',
                    ...(_selectedState != null && _selectedState != 'All'
                        ? stateDistricts[_selectedState]!
                        : []),
                  ],
                  isDark: isDark,
                  onChanged: (val) => setState(() => _selectedDistrict = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: Colors.grey[400],
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF334155),
          ),
          items:
              items
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildAdvocateCard(Map<String, dynamic> advocate, bool isDark) {
    final name = advocate['full_name'] ?? 'Unknown';
    final district = advocate['practice_district'];
    final state = advocate['practice_state'];
    final location =
        (district != null && state != null)
            ? '$district, $state'
            : (state ?? district ?? 'Location Unknown');
    final regNo = advocate['registration_number'] ?? 'Reg No. Not Provided';
    final mobile = advocate['mobile_number'];
    final email = advocate['email'];
    final address = advocate['office_address'];

    // Generate a consistent gradient from the name
    final colors = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
      [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
      [const Color(0xFFD97706), const Color(0xFFF59E0B)],
      [const Color(0xFFDC2626), const Color(0xFFEF4444)],
      [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
    ];
    final gradientPair = colors[name.hashCode.abs() % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE2E8F0),
        ),
        boxShadow:
            !isDark
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Avatar with gradient ring (photo or initials)
                ProfileAvatar(
                  avatarUrl: advocate['avatar_url'],
                  name: name,
                  radius: 24,
                  gradientColors: gradientPair,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color:
                              isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildInfoChip(
                        Icons.location_on_rounded,
                        location,
                        isDark,
                      ),
                      const SizedBox(height: 4),
                      _buildInfoChip(Icons.badge_rounded, regNo, isDark),
                      if (address != null && address.toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _buildInfoChip(Icons.business_rounded, address, isDark),
                      ],
                      if (email != null && email.toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _buildInfoChip(Icons.email_rounded, email, isDark),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Action Bar ──
          if (mobile != null && mobile.toString().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(
                  top: BorderSide(
                    color:
                        isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_rounded, size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mobile,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color:
                            isDark ? Colors.grey[300] : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  if (email != null && email.toString().isNotEmpty)
                    _buildActionButton(Icons.mail_outline_rounded, 'Email', () {
                      launchUrl(Uri.parse('mailto:$email'));
                    }),
                  const SizedBox(width: 8),
                  _buildActionButton(Icons.call_rounded, 'Call', () {
                    launchUrl(Uri.parse('tel:$mobile'));
                  }, isPrimary: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 13,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool isPrimary = false,
  }) {
    return Material(
      color:
          isPrimary
              ? AppTheme.accent.withValues(alpha: 0.1)
              : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppTheme.accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withValues(alpha: 0.08),
            ),
            child: Icon(
              Icons.people_outline_rounded,
              size: 48,
              color: AppTheme.accent.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Advocates Found',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Try adjusting your search or filters to find advocates in your area.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error, String filterKey, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withValues(alpha: 0.08),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connection Error',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed:
                  () => ref.invalidate(advocateSearchProvider(filterKey)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
