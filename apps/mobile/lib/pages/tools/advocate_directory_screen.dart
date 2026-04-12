import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/geo_data.dart';

// Provides the list of advocates based on current filters
// Provides the list of advocates based on current filters. 
// Adding a timeout to prevent infinite loading if the network or RLS is hanging.
final advocateSearchProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, filterKey) async {
  try {
    // Parse the filter key (format: "state|district|query")
    final parts = filterKey.split('|');
    final state = parts[0] == 'All' ? null : parts[0];
    final district = parts[1] == 'All' ? null : parts[1];
    final searchQuery = parts[2];

    var query = Supabase.instance.client
        .from('profiles')
        .select('id, full_name, email, mobile_number, practice_state, practice_district, office_address, registration_number')
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

    // Adding a 15-second timeout to force an error instead of infinite loading
    final response = await query.order('full_name').timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw 'Connection Timeout: The database is taking too long to respond. Please check your RLS policies or internet.',
    );
    
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    debugPrint("Advocate Search Error: $e");
    rethrow;
  }
});

class AdvocateDirectoryScreen extends ConsumerStatefulWidget {
  const AdvocateDirectoryScreen({super.key});

  @override
  ConsumerState<AdvocateDirectoryScreen> createState() => _AdvocateDirectoryScreenState();
}

class _AdvocateDirectoryScreenState extends ConsumerState<AdvocateDirectoryScreen> {
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
    // Listen for changes in the profiles table to keep the directory in sync
    _channel = Supabase.instance.client
        .channel('public:profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            // Update UI by invalidating the provider when any profile changes
            final filterKey = "$_selectedState|$_selectedDistrict|$_searchQuery";
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
    final filterKey = "$_selectedState|$_selectedDistrict|$_searchQuery";
    final advocatesAsync = ref.watch(advocateSearchProvider(filterKey));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("National Advocate Directory"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: advocatesAsync.when(
              data: (advocates) {
                if (advocates.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(advocateSearchProvider(filterKey)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: advocates.length,
                    itemBuilder: (context, index) {
                      final advocate = advocates[index];
                      return _buildAdvocateCard(advocate);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Error loading directory: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(advocateSearchProvider(filterKey)),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: "Search by Advocate Name...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 16),
          // Dropdowns Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedState,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "State",
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: ['All', ...stateDistricts.keys].map((state) {
                    return DropdownMenuItem<String>(value: state, child: Text(state, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedState = val;
                      _selectedDistrict = 'All'; // Reset district
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedDistrict,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "District",
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: ['All', ...(_selectedState != null && _selectedState != 'All' ? stateDistricts[_selectedState]! : [])].map((district) {
                    return DropdownMenuItem<String>(value: district, child: Text(district, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedDistrict = val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvocateCard(Map<String, dynamic> advocate) {
    final name = advocate['full_name'] ?? 'Unknown';
    final district = advocate['practice_district'];
    final state = advocate['practice_state'];
    final location = (district != null && state != null) ? '$district, $state' : (state ?? district ?? 'Location Unknown');
    final regNo = advocate['registration_number'] ?? 'Reg No. Not Provided';
    final mobile = advocate['mobile_number'];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    name.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.badge, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            regNo,
                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                          ),
                        ],
                      ),
                      if (advocate['office_address'] != null && advocate['office_address'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.home, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                advocate['office_address'],
                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (advocate['email'] != null && advocate['email'].toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.email, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                advocate['email'],
                                style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (mobile != null && mobile.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(mobile, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Row(
                      children: [
                        if (advocate['email'] != null && advocate['email'].toString().isNotEmpty) ...[
                          IconButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Emailing ${advocate['email']}...')));
                            },
                            icon: const Icon(Icons.mail_outline, size: 20),
                            color: AppTheme.primary,
                            tooltip: 'Send Email',
                          ),
                        ],
                        OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling $mobile...')));
                          },
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            "No Advocates Found",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your search or filters.",
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
