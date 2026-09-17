import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'case_conflict_dialog.dart';
import '../../services/supabase_service.dart';
import '../../services/firm_service.dart';
import '../../services/providers.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
      // 0. Refuse to file the same case twice.
      //
      // Scoped to number + court: case numbers repeat across courts, so an
      // OS/448/2022 in Tenkasi is not the OS/448/2022 in Madurai. A matching
      // title only warns — two unrelated matters are often named alike.
      final provisionalTitle = _titleController.text.trim();
      final conflicts = await SupabaseService.findConflictingCases(
        caseNumber: _numberController.text.trim(),
        courtName: _courtController.text.trim(),
        caseTitle: provisionalTitle.isEmpty ? null : provisionalTitle,
      );
      if (conflicts.isNotEmpty) {
        if (!mounted) return;
        final proceed = await showCaseConflictDialog(
          context,
          conflicts,
          onOpenExisting: (caseId) {
            // Close this form too, or the case opens behind it.
            Navigator.of(context).pop();
            context.go('/cases/$caseId');
          },
        );
        if (!proceed) {
          if (mounted) setState(() => _isSaving = false);
          return;
        }
      }

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
        // Off for new cases. The toggle that set this was the only control
        // for it anywhere in the app and has been removed; daily eCourts
        // polling costs Apify credits per case, so it is not switched on
        // silently. Re-introducing it means adding a deliberate per-case
        // setting, most naturally in the Case Dossier.
        'is_auto_sync_enabled': false,
      });

      ref.invalidate(casesProvider);
      ref.invalidate(clientsProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        // The unique index is the real guard — the pre-check above is only a
        // courtesy, and two devices saving at once still reach here.
        final message = SupabaseService.isDuplicateCaseError(e)
            ? 'This case already exists in the same court.'
            : 'Error: $e';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
              SizedBox(height: 8.h),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'Civil',
                    label: Text('Civil', style: TextStyle(fontSize: 12.sp)),
                  ),
                  ButtonSegment(
                    value: 'Criminal',
                    label: Text('Criminal', style: TextStyle(fontSize: 12.sp)),
                  ),
                ],
                selected: {_caseCategory},
                onSelectionChanged:
                    (val) => setState(() => _caseCategory = val.first),
              ),
              SizedBox(height: 16.h),

              // ─── COURT TYPE ───
              _sectionLabel('Court Type'),
              SizedBox(height: 8.h),
              SegmentedButton<CourtType>(
                segments:
                    CourtType.values
                        .map(
                          (t) => ButtonSegment(
                            value: t,
                            label: Text(
                              t.label,
                              style: TextStyle(fontSize: 12.sp),
                            ),
                          ),
                        )
                        .toList(),
                selected: {_courtType},
                onSelectionChanged:
                    (val) => setState(() => _courtType = val.first),
              ),
              SizedBox(height: 20.h),

              SegmentedButton<RepresentationType>(
                segments: [
                  ButtonSegment(
                    value: RepresentationType.petitioner,
                    label: Text(
                      _partyALabel,
                      style: TextStyle(fontSize: 12.sp),
                    ),
                  ),
                  ButtonSegment(
                    value: RepresentationType.respondent,
                    label: Text(
                      _partyBLabel,
                      style: TextStyle(fontSize: 12.sp),
                    ),
                  ),
                ],
                selected: {_representing},
                onSelectionChanged:
                    (val) => setState(() => _representing = val.first),
              ),
              SizedBox(height: 24.h),

              // ─── CNR ───
              // The CNR is kept because Track Case and eCourts lookups need
              // it. What was removed is the "Automated Monitoring" framing
              // and its toggle — see the note on is_auto_sync_enabled below.
              _buildPartySectionHeader(
                icon: Icons.qr_code_rounded,
                label: 'eCourts Reference',
                subtitle: 'Optional — needed to look this case up on eCourts',
                color: const Color(0xFF0F172A),
              ),
              SizedBox(height: 12.h),
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
              SizedBox(height: 24.h),

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
              SizedBox(height: 12.h),
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
              SizedBox(height: 12.h),
              TextFormField(
                controller: _plaintiffPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _plaintiffEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _plaintiffAdvocateController,
                decoration: InputDecoration(
                  labelText: '$_partyALabel Advocate Name',
                  prefixIcon: const Icon(Icons.gavel_outlined),
                ),
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _plaintiffAdvocatePhoneController,
                decoration: InputDecoration(
                  labelText: '$_partyALabel Advocate Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 20.h),

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
              SizedBox(height: 12.h),
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
              SizedBox(height: 12.h),
              TextFormField(
                controller: _defendantPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _defendantEmailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _defendantAdvocateController,
                decoration: const InputDecoration(
                  labelText: 'Advocate Name',
                  prefixIcon: Icon(Icons.gavel_outlined),
                ),
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _defendantAdvocatePhoneController,
                decoration: const InputDecoration(
                  labelText: 'Advocate Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 20.h),

              // ─── CASE DETAILS SECTION ───
              _buildPartySectionHeader(
                icon: Icons.folder_rounded,
                label: 'Case Details',
                subtitle: 'Filing information',
                color: AppTheme.accent,
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Case Title (auto-generated if empty)',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Case Number (optional)',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              SizedBox(height: 12.h),
              TextFormField(
                controller: _courtController,
                decoration: const InputDecoration(
                  labelText: 'Court Name',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                ),
              ),
              SizedBox(height: 12.h),
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
              SizedBox(height: 12.h),
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
              SizedBox(height: 12.h),
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
                SizedBox(height: 12.h),
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
                  ? SizedBox(
                    height: 20.h,
                    width: 20.w,
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
      style: TextStyle(
        fontSize: 11.sp,
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
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.sp,
                  color: color,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10.sp, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
