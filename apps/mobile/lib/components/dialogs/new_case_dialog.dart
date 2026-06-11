import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/firm_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';

class NewCaseDialog extends ConsumerStatefulWidget {
  const NewCaseDialog({super.key});

  @override
  ConsumerState<NewCaseDialog> createState() => _NewCaseDialogState();
}

class _NewCaseDialogState extends ConsumerState<NewCaseDialog> {
  final _formKey = GlobalKey<FormState>();

  // ─── Case Category ───
  String _caseCategory = 'Civil'; // Civil or Criminal
  RepresentationType _representing = RepresentationType.petitioner;

  // ─── Case Details ───
  final _titleController = TextEditingController();
  final _numberController = TextEditingController();
  final _courtController = TextEditingController();
  DateTime? _filingDate = DateTime.now();
  CaseStatus _status = CaseStatus.active;
  CaseStage _stage = CaseStage.filing;
  CourtType _courtType = CourtType.trial;
  final _cnrController = TextEditingController();
  bool _isAutoTrackingEnabled = true;

  // ─── Plaintiff / Petitioner (Your Client) ───
  final _plaintiffNameController = TextEditingController();
  final _plaintiffPhoneController = TextEditingController();
  final _plaintiffEmailController = TextEditingController();
  final _plaintiffAdvocateController = TextEditingController();
  final _plaintiffAdvocatePhoneController = TextEditingController();

  // ─── Defendant / Accused (Opposing Party) ───
  final _defendantNameController = TextEditingController();
  final _defendantPhoneController = TextEditingController();
  final _defendantEmailController = TextEditingController();
  final _defendantAdvocateController = TextEditingController();
  final _defendantAdvocatePhoneController = TextEditingController();

  bool _isSaving = false;
  String? _assignedTo;
  List<FirmMember> _firmMembers = [];

  // Dynamic labels based on case category & court type
  String get _partyALabel {
    if (_caseCategory == 'Criminal') return 'Petitioner / Complainant';
    return _courtType == CourtType.trial ? 'Plaintiff' : 'Petitioner';
  }

  String get _partyBLabel {
    if (_caseCategory == 'Criminal') return 'Accused / Respondent';
    return _courtType == CourtType.trial ? 'Defendant' : 'Respondent';
  }

  @override
  void initState() {
    super.initState();
    _loadFirmMembers();
  }

  Future<void> _loadFirmMembers() async {
    final profile = await ref.read(userProfileProvider.future);
    if (profile.isFirmOwner) {
      try {
        final members = await FirmService.fetchFirmMembers();
        if (mounted) {
          setState(() {
            _firmMembers =
                members.where((m) => m.status == 'accepted').toList();
          });
        }
      } catch (e) {
        debugPrint('Error loading firm members: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _numberController.dispose();
    _courtController.dispose();
    _plaintiffNameController.dispose();
    _plaintiffPhoneController.dispose();
    _plaintiffEmailController.dispose();
    _plaintiffAdvocateController.dispose();
    _plaintiffAdvocatePhoneController.dispose();
    _defendantNameController.dispose();
    _defendantPhoneController.dispose();
    _defendantEmailController.dispose();
    _defendantAdvocateController.dispose();
    _defendantAdvocatePhoneController.dispose();
    _cnrController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      // 1. Auto-create or find client from the selected representing party
      final isRepresentingA = _representing == RepresentationType.petitioner;
      final clientName =
          isRepresentingA
              ? _plaintiffNameController.text.trim()
              : _defendantNameController.text.trim();
      final clientPhone =
          isRepresentingA
              ? _plaintiffPhoneController.text
              : _defendantPhoneController.text;
      final clientEmail =
          isRepresentingA
              ? _plaintiffEmailController.text
              : _defendantEmailController.text;

      String? clientId;

      final existingClients = await SupabaseService.fetchClients();
      final match = existingClients.where(
        (c) => c.name.toLowerCase() == clientName.toLowerCase(),
      );

      if (match.isNotEmpty) {
        clientId = match.first.id;
      } else {
        final newClient = await SupabaseService.createClient({
          'name': clientName,
          'phone': clientPhone.isNotEmpty ? clientPhone : null,
          'email': clientEmail.isNotEmpty ? clientEmail : null,
        });
        clientId = newClient.id;
      }

      // 2. Auto-generate case title if not provided
      String caseTitle = _titleController.text.trim();
      if (caseTitle.isEmpty) {
        final defName = _defendantNameController.text.trim();
        caseTitle = defName.isNotEmpty ? '$clientName vs $defName' : clientName;
      }

      // 3. Create the case
      await SupabaseService.createCase({
        'client_id': clientId,
        'case_title': caseTitle,
        'case_number': _numberController.text,
        'case_type': _caseCategory,
        'court_name': _courtController.text,
        'filing_date': DateFormat('yyyy-MM-dd').format(_filingDate!),
        'status': _status.name,
        'stage': _stage.name,
        'assigned_to': _assignedTo,
        'court_type': _courtType.name,
        'representation_type': _representing.name,
        'opposing_party':
            isRepresentingA
                ? _defendantNameController.text
                : _plaintiffNameController.text,
        'opposing_advocate': _defendantAdvocateController.text,
        'opposing_advocate_phone': _defendantAdvocatePhoneController.text,
        'petitioner_advocate_phone': _plaintiffAdvocatePhoneController.text,
        'cnr_number': _cnrController.text.trim().toUpperCase(),
        'is_auto_sync_enabled':
            _cnrController.text.trim().isNotEmpty && _isAutoTrackingEnabled,
      });

      ref.invalidate(casesProvider);
      ref.invalidate(clientsProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      data: (profile) {
        return _buildForm(context);
      },

      loading:
          () => const AlertDialog(
            content: Center(child: CircularProgressIndicator()),
          ),
      error: (e, s) => AlertDialog(content: Text('Error loading profile: $e')),
    );
  }

  Widget _buildForm(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Create New Case',
        style: TextStyle(
          fontFamily: 'Playfair Display',
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── CASE CATEGORY ───
              _sectionLabel('Case Category'),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'Civil',
                    label: Text('Civil', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: 'Criminal',
                    label: Text('Criminal', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_caseCategory},
                onSelectionChanged:
                    (val) => setState(() => _caseCategory = val.first),
              ),
              const SizedBox(height: 16),

              // ─── COURT TYPE ───
              _sectionLabel('Court Type'),
              const SizedBox(height: 8),
              SegmentedButton<CourtType>(
                segments:
                    CourtType.values
                        .map(
                          (t) => ButtonSegment(
                            value: t,
                            label: Text(
                              t.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                selected: {_courtType},
                onSelectionChanged:
                    (val) => setState(() => _courtType = val.first),
              ),
              const SizedBox(height: 20),

              SegmentedButton<RepresentationType>(
                segments: [
                  ButtonSegment(
                    value: RepresentationType.petitioner,
                    label: Text(
                      _partyALabel,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  ButtonSegment(
                    value: RepresentationType.respondent,
                    label: Text(
                      _partyBLabel,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                selected: {_representing},
                onSelectionChanged:
                    (val) => setState(() => _representing = val.first),
              ),
              const SizedBox(height: 24),

              // ─── AUTO TRACKING (CNR) ───
              _buildPartySectionHeader(
                icon: Icons.auto_awesome_rounded,
                label: 'Automated Monitoring',
                subtitle: 'CNR Number is mandatory for background sync',
                color: const Color(0xFF0F172A),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cnrController,
                decoration: InputDecoration(
                  labelText: 'CNR Number',
                  prefixIcon: const Icon(Icons.qr_code_rounded),
                  hintText: 'E.g. PBJL010012342024',
                  suffixIcon:
                      _cnrController.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed:
                                () => setState(() => _cnrController.clear()),
                          )
                          : null,
                ),
                onChanged: (v) => setState(() {}),
                textCapitalization: TextCapitalization.characters,
              ),
              if (_cnrController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SwitchListTile(
                    title: const Text(
                      'Enable Background Tracking',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      "We'll poll eCourts daily for updates",
                      style: TextStyle(fontSize: 11),
                    ),
                    value: _isAutoTrackingEnabled,
                    onChanged:
                        (v) => setState(() => _isAutoTrackingEnabled = v),
                    activeThumbColor: AppTheme.accent,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const SizedBox(height: 24),

              // ─── PLAINTIFF / PETITIONER SECTION ───
              _buildPartySectionHeader(
                icon: Icons.person_rounded,
                label: '$_partyALabel Details',
                subtitle:
                    _representing == RepresentationType.petitioner
                        ? 'Your Client'
                        : 'Opposing Side',
                color: const Color(0xFF2563EB),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plaintiffNameController,
                decoration: InputDecoration(
                  labelText: '$_partyALabel Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  hintText: 'Enter full name',
                ),
                validator:
                    (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plaintiffPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plaintiffEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plaintiffAdvocateController,
                decoration: InputDecoration(
                  labelText: '$_partyALabel Advocate Name',
                  prefixIcon: const Icon(Icons.gavel_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plaintiffAdvocatePhoneController,
                decoration: InputDecoration(
                  labelText: '$_partyALabel Advocate Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              // ─── DEFENDANT / ACCUSED SECTION ───
              _buildPartySectionHeader(
                icon: Icons.person_off_rounded,
                label: '$_partyBLabel Details',
                subtitle:
                    _representing == RepresentationType.respondent
                        ? 'Your Client'
                        : 'Opposing Side',
                color: const Color(0xFFDC2626),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _defendantNameController,
                decoration: InputDecoration(
                  labelText: '$_partyBLabel Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  hintText: 'Enter full name',
                ),
                validator:
                    (v) =>
                        (_representing == RepresentationType.respondent &&
                                (v == null || v.trim().isEmpty))
                            ? 'Required'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _defendantPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _defendantEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _defendantAdvocateController,
                decoration: const InputDecoration(
                  labelText: 'Advocate Name',
                  prefixIcon: Icon(Icons.gavel_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _defendantAdvocatePhoneController,
                decoration: const InputDecoration(
                  labelText: 'Advocate Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),

              // ─── CASE DETAILS SECTION ───
              _buildPartySectionHeader(
                icon: Icons.folder_rounded,
                label: 'Case Details',
                subtitle: 'Filing information',
                color: AppTheme.accent,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Case Title (auto-generated if empty)',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Case Number (optional)',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _courtController,
                decoration: const InputDecoration(
                  labelText: 'Court Name',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _filingDate ?? DateTime.now(),
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _filingDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Filing Date',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_filingDate!)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CaseStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Initial Status'),
                items:
                    CaseStatus.values
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.label)),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _status = val!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CaseStage>(
                initialValue: _stage,
                decoration: const InputDecoration(labelText: 'Initial Stage'),
                items:
                    CaseStage.values
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.label)),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _stage = val!),
              ),
              if (_firmMembers.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _assignedTo,
                  decoration: const InputDecoration(
                    labelText: 'Assign to Advocate',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Me (Senior)'),
                    ),
                    ..._firmMembers.map(
                      (m) => DropdownMenuItem(
                        value: m.memberId,
                        child: Text(m.memberName ?? m.memberEmail),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _assignedTo = val),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child:
              _isSaving
                  ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('Create Case'),
        ),
      ],
    );
  }

  // ─── HELPERS ───

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Colors.grey,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildPartySectionHeader({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
