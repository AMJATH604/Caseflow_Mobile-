import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';
import '../services/back_interceptors.dart';
import '../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../components/epay_court_fee_sheet.dart';
import 'tools/court_fee_calculator.dart';
import 'tools/interest_calculator.dart';
import 'tools/delay_calculator.dart';
import 'tools/limitation_calculator.dart';
import 'tools/bare_acts_screen.dart';
import 'tools/case_import_export_screen.dart';
import 'tools/broadcast_node.dart';
import 'tools/associate_hub.dart';
import 'tools/court_holiday_list.dart';
import 'tools/legal_templates_screen.dart';
import 'tools/stamp_value_screen.dart';
import 'tools/partition_calculator.dart';
import 'tools/mact_calculator.dart';
import 'tools/maintenance_calculator.dart';
import 'tools/legal_dictionary.dart';
import 'tools/english_dictionary.dart';
import 'tools/document_tools/compare_pdf_tool.dart';
import 'tools/document_tools/images_to_pdf_tool.dart';
import 'tools/document_tools/merge_pdf_tool.dart';
import 'tools/document_tools/organize_pdf_tool.dart';
import 'tools/document_tools/page_editor_tool.dart';
import 'tools/document_tools/page_numbers_tool.dart';
import 'tools/document_tools/pdf_maintenance_tools.dart';
import 'tools/document_tools/pdf_to_images_tool.dart';
import 'tools/document_tools/prepare_efiling_screen.dart';
import 'tools/document_tools/server_tool_screen.dart';
import '../services/document_tools/server_tools_client.dart';
import 'tools/document_tools/split_pdf_tool.dart';
import 'tools/document_tools/watermark_tool.dart';
import 'cross_exam_sessions_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  String? _activeToolId;

  /// Back closes the open tool first. Tools are rendered from state, not the
  /// router, so without this the shell treats back as "leave the Tools tab".
  bool _handleBackPress() {
    if (_activeToolId == null) return false;
    setState(() => _activeToolId = null);
    return true;
  }

  @override
  void initState() {
    super.initState();
    BackInterceptors.add(_handleBackPress);
  }

  @override
  void dispose() {
    BackInterceptors.remove(_handleBackPress);
    super.dispose();
  }

  /// PDF tools for preparing e-filing documents. They run on the device, so
  /// files never leave the phone unless the user saves them to a case.
  final List<Map<String, dynamic>> _documentTools = [
    {
      'id': 'doc_prepare_efiling',
      'title': 'Prepare e-Filing',
      'desc': 'Court-ready PDF',
      'icon': Icons.fact_check_rounded,
      'color': const Color(0xFF059669),
      'plan': 'free',
    },
    {
      'id': 'doc_scan',
      'title': 'Scan to PDF',
      'desc': 'Camera scanner',
      'icon': Icons.document_scanner_rounded,
      'color': const Color(0xFF0EA5E9),
      'plan': 'free',
    },
    {
      'id': 'doc_images_to_pdf',
      'title': 'Images to PDF',
      'desc': 'Photos, WhatsApp',
      'icon': Icons.image_rounded,
      'color': const Color(0xFFF59E0B),
      'plan': 'free',
    },
    {
      'id': 'doc_merge',
      'title': 'Merge PDF',
      'desc': 'Combine files',
      'icon': Icons.merge_rounded,
      'color': const Color(0xFF8B5CF6),
      'plan': 'free',
    },
    {
      'id': 'doc_split',
      'title': 'Split PDF',
      'desc': 'Extract pages',
      'icon': Icons.call_split_rounded,
      'color': const Color(0xFFEF4444),
      'plan': 'free',
    },
    {
      'id': 'doc_organize',
      'title': 'Organize Pages',
      'desc': 'Reorder, delete',
      'icon': Icons.view_list_rounded,
      'color': const Color(0xFF10B981),
      'plan': 'free',
    },
    {
      'id': 'doc_rotate',
      'title': 'Rotate PDF',
      'desc': 'Fix sideways pages',
      'icon': Icons.rotate_right_rounded,
      'color': const Color(0xFF6366F1),
      'plan': 'free',
    },
    {
      'id': 'doc_page_numbers',
      'title': 'Page Numbers',
      'desc': 'Number pages',
      'icon': Icons.format_list_numbered_rounded,
      'color': const Color(0xFF2563EB),
      'plan': 'free',
    },
    {
      'id': 'doc_sign',
      'title': 'Sign PDF',
      'desc': 'Signature, date, seal',
      'icon': Icons.draw_rounded,
      'color': const Color(0xFF1E3A8A),
      'plan': 'free',
    },
    {
      'id': 'doc_edit',
      'title': 'Edit PDF',
      'desc': 'Text, whiteout, redact',
      'icon': Icons.edit_note_rounded,
      'color': const Color(0xFFEA580C),
      'plan': 'free',
    },
    {
      'id': 'doc_watermark',
      'title': 'Watermark',
      'desc': 'Draft, copy, confidential',
      'icon': Icons.branding_watermark_rounded,
      'color': const Color(0xFF64748B),
      'plan': 'free',
    },
    {
      'id': 'doc_compare',
      'title': 'Compare PDF',
      'desc': 'What changed',
      'icon': Icons.compare_rounded,
      'color': const Color(0xFF0891B2),
      'plan': 'free',
    },
    {
      'id': 'doc_compress',
      'title': 'Compress PDF',
      'desc': 'Fit upload limit',
      'icon': Icons.compress_rounded,
      'color': const Color(0xFFDC2626),
      'plan': 'free',
    },
    {
      'id': 'doc_protect',
      'title': 'Protect PDF',
      'desc': 'Add a password',
      'icon': Icons.lock_rounded,
      'color': const Color(0xFF7C3AED),
      'plan': 'free',
    },
    {
      'id': 'doc_unlock',
      'title': 'Unlock PDF',
      'desc': 'Remove password',
      'icon': Icons.lock_open_rounded,
      'color': const Color(0xFF9333EA),
      'plan': 'free',
    },
    {
      'id': 'doc_repair',
      'title': 'Repair PDF',
      'desc': 'Fix damaged PDF',
      'icon': Icons.build_rounded,
      'color': const Color(0xFF64748B),
      'plan': 'free',
    },
    {
      'id': 'doc_pdf_to_jpg',
      'title': 'PDF to JPG',
      'desc': 'Pages as images',
      'icon': Icons.photo_rounded,
      'color': const Color(0xFFD97706),
      'plan': 'free',
    },
  ];

  /// Tools that run on the CaseFlow document server; listed only when this
  /// build knows the server's address (DOC_TOOLS_API_URL).
  static final List<Map<String, dynamic>> _serverTools = [
    for (final (tool, desc, color) in const [
      (ServerTool.wordToPdf, 'Pleadings to PDF', Color(0xFF2563EB)),
      (ServerTool.ocr, 'Searchable scans', Color(0xFF0D9488)),
      (ServerTool.pdfToWord, 'Editable Word', Color(0xFF1D4ED8)),
      (ServerTool.pdfToExcel, 'Tables to Excel', Color(0xFF059669)),
      (ServerTool.excelToPdf, 'Sheets to PDF', Color(0xFF16A34A)),
      (ServerTool.powerpointToPdf, 'Slides to PDF', Color(0xFFEA580C)),
    ])
      {
        'id': 'srv_${tool.slug}',
        'title': tool.title,
        'desc': desc,
        'icon': tool.icon,
        'color': color,
        'plan': 'free',
        'server': tool,
      },
  ];

  final List<Map<String, dynamic>> _legalTools = [
    {
      'id': 'cross_exam',
      'title': 'Cross-Exam Prep',
      'desc': 'Prepare witness questions',
      'icon': Icons.gavel_rounded,
      'color': const Color(0xFFDC2626),
      'plan': 'pro',
    },
    {
      'id': 'ai_chat',
      'title': 'AI Legal Assistant',
      'desc': 'Ask Gemini legal questions',
      'icon': Icons.auto_awesome,
      'color': const Color(0xFF6366F1),
      'plan': 'premium',
    },
    {
      'id': 'advocate_directory',
      'title': 'Advocate Directory',
      'desc': 'Find peers across India',
      'icon': Icons.contact_page_rounded,
      'color': Colors.indigo,
      'plan': 'free',
    },
    {
      'id': 'legal_pulse',
      'title': 'Legal Pulse',
      'desc': 'Live legal news feed',
      'icon': Icons.newspaper_rounded,
      'color': const Color(0xFFDC2626),
      'plan': 'free',
    },
    {
      'id': 'partition_calculator',
      'title': 'Partition Share',
      'desc': 'Hindu & Muslim Law',
      'icon': Icons.family_restroom,
      'color': Colors.pink,
      'plan': 'free',
    },
    {
      'id': 'mact_calculator',
      'title': 'MACT Claims',
      'desc': 'Accident Compensation',
      'icon': Icons.directions_car,
      'color': Colors.red,
      'plan': 'free',
    },
    {
      'id': 'maintenance_calculator',
      'title': 'Maintenance',
      'desc': 'Sec 144 BNSS / HAMA',
      'icon': Icons.account_balance_wallet,
      'color': Colors.deepPurple,
      'plan': 'free',
    },
    {
      'id': 'legal_dictionary',
      'title': 'Legal Dictionary',
      'desc': '500+ Latin & Legal terms',
      'icon': Icons.import_contacts_rounded,
      'color': Colors.orange,
      'plan': 'free',
    },
    {
      'id': 'english_dictionary',
      'title': 'English Dictionary',
      'desc': 'Curated A-Z Vocabulary',
      'icon': Icons.spellcheck_rounded,
      'color': Colors.teal,
      'plan': 'free',
    },
    {
      'id': 'court-fee',
      'title': 'Court Fee',
      'desc': 'Calculate fees',
      'icon': Icons.calculate,
      'color': Colors.orange,
      'plan': 'free',
    },
    {
      'id': 'epay_court_fee',
      'title': 'eCourts ePay',
      'desc': 'Pay court fees online',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFF2563EB),
      'plan': 'free',
    },
    {
      'id': 'interest',
      'title': 'Interest',
      'desc': 'Calculate interest',
      'icon': Icons.percent,
      'color': Colors.purple,
      'plan': 'free',
    },
    {
      'id': 'delay',
      'title': 'Delay (Sec 5)',
      'desc': 'Calculate delay',
      'icon': Icons.schedule,
      'color': Colors.red,
      'plan': 'free',
    },
    {
      'id': 'limitation',
      'title': 'Limitation',
      'desc': 'Track deadlines',
      'icon': Icons.timer,
      'color': Colors.teal,
      'plan': 'free',
    },
    {
      'id': 'bare_acts',
      'title': 'Bare Acts Library',
      'desc': 'Offline statutes',
      'icon': Icons.library_books,
      'color': Colors.brown,
      'plan': 'free',
    },
    {
      'id': 'import_export',
      'title': 'Import/Export',
      'desc': 'ECourts & Backups',
      'icon': Icons.swap_vertical_circle_rounded,
      'color': Colors.blueGrey,
      'plan': 'free',
    },
    {
      'id': 'holiday_list',
      'title': 'Holiday List',
      'desc': 'Court holidays 2026',
      'icon': Icons.calendar_month_rounded,
      'color': Colors.deepOrange,
      'plan': 'free',
    },
    {
      'id': 'legal_templates',
      'title': 'Legal Templates',
      'desc': 'PDF & Word Drafts',
      'icon': Icons.description_rounded,
      'color': AppTheme.accent,
      'plan': 'free',
    },
    {
      'id': 'stamp_values',
      'title': 'Stamp Values',
      'desc': 'Petition stamp reference',
      'icon': Icons.receipt_long_rounded,
      'color': Colors.amber,
      'plan': 'free',
    },
  ];

  final List<Map<String, dynamic>> _chambersTools = [
    {
      'id': 'broadcast',
      'title': 'Digital Chambers',
      'desc': 'Connect with Firm',
      'icon': Icons.hub_rounded,
      'color': AppTheme.accent,
      'plan': 'business',
    },
    {
      'id': 'associate',
      'title': 'Recruit Associate',
      'desc': 'Manage Talent',
      'icon': Icons.people_alt_rounded,
      'color': AppTheme.accentViolet,
      'plan': 'business',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child:
            _activeToolId == null
                ? _buildSelectionGrid(isMobile)
                : _buildToolView(),
      ),
    );
  }

  Widget _buildSelectionGrid(bool isMobile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Intelligence Hub',
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(fontSize: 28.sp),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Specialized utilities for high-precision practice',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFCBD5E1)
                            : Colors.black38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          // Order is deliberate: the legal tools are what an advocate opens
          // most, document utilities next, then chambers, and recruiting last.
          _buildToolSection(
            'Legal Tools',
            _legalTools.where((t) {
              if (kIsWeb && t['id'] == 'import_export') return false;
              return true;
            }).toList(),
            isMobile,
          ),
          SizedBox(height: 20.h),
          _buildToolSection(
            'Document Tools',
            _documentTools.where((t) {
              // The camera scanner is a phone feature.
              if (kIsWeb && t['id'] == 'doc_scan') return false;
              return true;
            }).toList(),
            isMobile,
          ),
          SizedBox(height: 20.h),
          if (ServerToolsClient.isConfigured) ...[
            _buildToolSection('Convert & OCR', _serverTools, isMobile),
            SizedBox(height: 20.h),
          ],
          // Separate Chambers sections for high visibility
          _buildToolSection('Digital Chambers', [_chambersTools[0]], isMobile),
          SizedBox(height: 20.h),
          _buildToolSection('Recruit Associate', [_chambersTools[1]], isMobile),

          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  Widget _buildToolSection(
    String title,
    List<Map<String, dynamic>> tools,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
          child: Row(
            children: [
              Container(
                width: 4.w,
                height: 20.h,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 3 : 6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _buildToolCard(tool);
          },
        ),
      ],
    );
  }

  Widget _buildToolCard(Map<String, dynamic> tool) {
    return InkWell(
      onTap: () => _onToolTap(tool),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: AppTheme.cardDecoration(
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: tool['color'].withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: tool['color'].withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(tool['icon'], color: tool['color'], size: 20),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    tool['title'],
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 11.sp,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: Text(
                      tool['desc'].toString().toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 8.sp,
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFCBD5E1)
                                : Colors.black38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onToolTap(Map<String, dynamic> tool) {
    // Track tool usage in Firebase Analytics
    AnalyticsService.logToolUsed(tool['id'].toString());

    if (tool['id'] == 'ai_chat') {
      context.push('/ai-chat');
    } else if (tool['id'] == 'cross_exam') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CrossExamSessionsScreen()),
      );
    } else if (tool['id'] == 'doc_prepare_efiling') {
      PrepareEfilingScreen.open(context);
    } else if (tool['id'] == 'advocate_directory') {
      context.push('/advocate-directory');
    } else if (tool['id'] == 'epay_court_fee') {
      EPayCourtFeeSheet.show(context);
    } else if (tool['id'] == 'legal_pulse') {
      context.push('/legal-pulse');
    } else if (tool['id'] == 'broadcast') {
      context.push('/chambers-chat');
    } else {
      setState(() => _activeToolId = tool['id']);
    }
  }

  Widget _buildToolView() {
    final allTools = [
      ..._documentTools,
      ..._serverTools,
      ..._legalTools,
      ..._chambersTools,
    ];
    final tool = allTools.firstWhere((t) => t['id'] == _activeToolId);
    Widget toolWidget;
    final String title = tool['title'];

    switch (_activeToolId) {
      case 'court-fee':
        toolWidget = const CourtFeeCalculator();
        break;
      case 'interest':
        toolWidget = const InterestCalculator();
        break;
      case 'delay':
        toolWidget = const DelayCalculator();
        break;
      case 'limitation':
        toolWidget = const LimitationCalculator();
        break;
      case 'partition_calculator':
        toolWidget = const PartitionCalculator();
        break;
      case 'mact_calculator':
        toolWidget = const MactCalculator();
        break;
      case 'maintenance_calculator':
        toolWidget = const MaintenanceCalculator();
        break;
      case 'legal_dictionary':
        toolWidget = const LegalDictionary();
        break;
      case 'english_dictionary':
        toolWidget = const EnglishDictionary();
        break;
      case 'bare_acts':
        toolWidget = const BareActsLibraryScreen();
        break;
      case 'import_export':
        toolWidget =
            kIsWeb
                ? const Center(
                  child: Text('Import/Export is currently mobile-only.'),
                )
                : const CaseImportExportScreen();
        break;
      case 'broadcast':
        toolWidget = const BroadcastNode();
        break;
      case 'associate':
        toolWidget = const AssociateHub();
        break;
      case 'holiday_list':
        toolWidget = const CourtHolidayList();
        break;
      case 'legal_templates':
        toolWidget = const LegalTemplatesScreen();
        break;
      case 'stamp_values':
        toolWidget = const StampValueScreen();
        break;
      case 'cross_exam':
        toolWidget = const CrossExamSessionsScreen();
        break;
      case 'doc_scan':
        toolWidget = const ImagesToPdfTool(mode: ImageSourceMode.scan);
        break;
      case 'doc_images_to_pdf':
        toolWidget = const ImagesToPdfTool(mode: ImageSourceMode.images);
        break;
      case 'doc_merge':
        toolWidget = const MergePdfTool();
        break;
      case 'doc_split':
        toolWidget = const SplitPdfTool();
        break;
      case 'doc_organize':
        toolWidget = const OrganizePdfTool();
        break;
      case 'doc_rotate':
        toolWidget = const OrganizePdfTool(mode: PageEditorMode.rotate);
        break;
      case 'doc_page_numbers':
        toolWidget = const PageNumbersTool();
        break;
      case 'doc_sign':
        toolWidget = const PageEditorTool(mode: MarkupMode.sign);
        break;
      case 'doc_edit':
        toolWidget = const PageEditorTool(mode: MarkupMode.edit);
        break;
      case 'doc_watermark':
        toolWidget = const WatermarkTool();
        break;
      case 'doc_compare':
        toolWidget = const ComparePdfTool();
        break;
      case 'doc_compress':
        toolWidget = const CompressPdfTool();
        break;
      case 'doc_protect':
        toolWidget = const PasswordPdfTool(mode: PasswordMode.protect);
        break;
      case 'doc_unlock':
        toolWidget = const PasswordPdfTool(mode: PasswordMode.unlock);
        break;
      case 'doc_repair':
        toolWidget = const RepairPdfTool();
        break;
      case 'doc_pdf_to_jpg':
        toolWidget = const PdfToImagesTool();
        break;
      default:
        final server = tool['server'];
        toolWidget =
            server is ServerTool
                ? ServerToolScreen(tool: server)
                : Center(child: Text('Tool: $_activeToolId'));
    }

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (true) // Enable header for all tools including broadcast
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _activeToolId = null),
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: 16.h),

        Expanded(child: toolWidget),
      ],
    );
  }
}
