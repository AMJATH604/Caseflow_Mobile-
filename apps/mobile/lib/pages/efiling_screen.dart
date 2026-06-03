import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/providers.dart';
import '../components/error_state_widget.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../components/status_badge.dart';
import '../components/empty_state_widget.dart';
import 'package:caseflow/components/dialogs/new_case_dialog.dart';

class EFilingScreen extends ConsumerWidget {
  const EFilingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(efilingProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isMobile),
            const SizedBox(height: 24),
            Expanded(
              child: recordsAsync.when(
                data:
                    (records) => _buildRecordsList(context, isMobile, records),
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (err, stack) => ErrorStateWidget(
                      error: err,
                      onRetry: () => ref.invalidate(efilingProvider),
                    ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          isMobile
              ? FloatingActionButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const NewCaseDialog(),
                  );
                },
                backgroundColor: AppTheme.primary,
                child: const Icon(Icons.add, color: Color(0xFF1E293B)),
              )
              : null,
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "E-Filing",
              style: TextStyle(
                fontSize: isMobile ? 24 : 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Playfair Display',
              ),
            ),
            const Text(
              "Track filing progress",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        if (!isMobile)
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const NewCaseDialog(),
              );
            },
            icon: const Icon(Icons.plus_one),
            label: const Text("New Filing"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildRecordsList(
    BuildContext context,
    bool isMobile,
    List<EFilingRecord> records,
  ) {
    if (records.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.cloud_upload_outlined,
        title: "No E-Filings Yet",
        message:
            "You haven't initiated any electronic filings. When you e-file a case, its tracking status will appear here.",
        buttonText: "New E-Filing",
        onButtonTap: () {
          showDialog(
            context: context,
            builder: (context) => const NewCaseDialog(),
          );
        },
      );
    }

    if (isMobile) {
      return ListView.builder(
        itemCount: records.length,
        itemBuilder: (context, index) {
          final r = records[index];
          final double progress = _getProgress(r.status.name);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          r.caseTitle ?? "Unknown Case",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      StatusBadge(status: r.status.name),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    r.documentType.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    color:
                        r.status.name == "defect"
                            ? Colors.red
                            : AppTheme.primary,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  if (r.defectNotes != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "DEFECT: ${r.defectNotes}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      );
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text("Case")),
        DataColumn(label: Text("Document")),
        DataColumn(label: Text("Status")),
        DataColumn(label: Text("Defect Notes")),
      ],
      rows:
          records.map((r) {
            return DataRow(
              cells: [
                DataCell(Text(r.caseTitle ?? "—")),
                DataCell(Text(r.documentType)),
                DataCell(StatusBadge(status: r.status.name)),
                DataCell(
                  Text(
                    r.defectNotes ?? "—",
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  double _getProgress(String status) {
    const steps = [
      "drafting",
      "review",
      "signature_pending",
      "filed",
      "accepted",
    ];
    if (status == "defect") return 0.0;
    int index = steps.indexOf(status);
    if (index == -1) return 0.0;
    return (index + 1) / steps.length;
  }
}
