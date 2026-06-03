import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';

class GlobalSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.length < 3) {
      return const Center(child: Text("Start typing to search..."));
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder<Map<String, List<dynamic>>>(
      future: SupabaseService.searchAll(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData ||
            snapshot.data!.values.every((v) => v.isEmpty)) {
          return const Center(child: Text("No results found."));
        }

        final cases = snapshot.data!['cases']!;
        final clients = snapshot.data!['clients']!;

        return ListView(
          children: [
            if (cases.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "CASES",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ...cases.map(
                (c) => ListTile(
                  leading: const Icon(Icons.work),
                  title: Text(c['case_title']),
                  subtitle: Text(c['case_number'] ?? ''),
                  onTap: () {
                    close(context, null);
                    context.push('/cases/${c['id']}');
                  },
                ),
              ),
            ],
            if (clients.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "CLIENTS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
              ...clients.map(
                (c) => ListTile(
                  leading: const Icon(Icons.people),
                  title: Text(c['name']),
                  onTap: () {
                    close(context, null);
                    context.go('/clients');
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
