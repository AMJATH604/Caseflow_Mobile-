import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import '../components/epay_court_fee_sheet.dart';
import 'tools/court_fee_calculator.dart';
import 'tools/interest_calculator.dart';
import 'tools/delay_calculator.dart';
import 'tools/limitation_calculator.dart';
// import 'tools/ocr_tool.dart'; // Mobile-only
import 'tools/bare_acts_screen.dart';
import 'tools/case_import_export_screen.dart';
// import 'tools/generic_pdf_tool.dart'; // Mobile-only
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
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> {
  String? _activeToolId;

  final List<Map<String, dynamic>> _documentTools = [
    {
      'id': 'officepdf',
      'title': 'Word to PDF',
      'desc': 'Convert DOCX to PDF',
      'icon': Icons.picture_as_pdf,
      'color': Colors.blue,
      'ext': ['doc', 'docx'],
      'target': 'pdf',
      'plan': 'pro',
    },
    {
      'id': 'pdfword',
      'title': 'PDF to Word',
      'desc': 'Convert PDF to DOCX',
      'icon': Icons.description,
      'color': Colors.indigo,
      'ext': ['pdf'],
      'target': 'docx',
      'plan': 'pro',
    },
    {
      'id': 'pdfocr',
      'title': 'OCR (Searchable)',
      'desc': 'Make PDF searchable',
      'icon': Icons.document_scanner,
      'color': Colors.green,
      'ext': ['pdf'],
      'target': 'pdf',
      'params': {'ocr_language': 'eng'},
      'plan': 'pro',
    },
    {
      'id': 'ocr',
      'title': 'OCR Scanner',
      'desc': 'Extract text from photo',
      'icon': Icons.camera_alt,
      'color': Colors.cyan,
      'plan': 'pro',
    },
    {
      'id': 'merge',
      'title': 'Merge PDF',
      'desc': 'Combine multiple PDFs',
      'icon': Icons.call_merge,
      'color': Colors.orange,
      'ext': ['pdf'],
      'target': 'pdf',
      'plan': 'pro',
    },
    {
      'id': 'split',
      'title': 'Split PDF',
      'desc': 'Separate PDF pages',
      'icon': Icons.call_split,
      'color': Colors.red,
      'ext': ['pdf'],
      'target': 'zip',
      'plan': 'pro',
    },
    {
      'id': 'compress',
      'title': 'Compress PDF',
      'desc': 'Reduce file size',
      'icon': Icons.compress,
      'color': Colors.teal,
      'ext': ['pdf'],
      'target': 'pdf',
      'plan': 'pro',
    },
    {
      'id': 'imagepdf',
      'title': 'JPG to PDF',
      'desc': 'Images to PDF',
      'icon': Icons.image,
      'color': Colors.deepPurple,
      'ext': ['jpg', 'jpeg', 'png'],
      'target': 'pdf',
      'plan': 'pro',
    },
    {
      'id': 'pdfjpg',
      'title': 'PDF to JPG',
      'desc': 'Extract images',
      'icon': Icons.collections,
      'color': Colors.pink,
      'ext': ['pdf'],
      'target': 'zip',
      'plan': 'pro',
    },
    {
      'id': 'watermark',
      'title': 'Watermark',
      'desc': 'Add stamp to PDF',
      'icon': Icons.branding_watermark,
      'color': Colors.blueGrey,
      'ext': ['pdf'],
      'target': 'pdf',
      'params': {'text': 'CASEFLOW'},
      'plan': 'pro',
    },
    {
      'id': 'rotate',
      'title': 'Rotate PDF',
      'desc': 'Fix orientation',
      'icon': Icons.rotate_right,
      'color': Colors.amber,
      'ext': ['pdf'],
      'target': 'pdf',
      'params': {'rotate': 90},
      'plan': 'pro',
    },
  ];

  final List<Map<String, dynamic>> _legalTools = [
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
          _buildToolSection(
            'Legal Tools',
            _legalTools.where((t) {
              if (kIsWeb && t['id'] == 'import_export') return false;
              return true;
            }).toList(),
            isMobile,
          ),
          SizedBox(height: 20.h),
          if (!kIsWeb) ...[
            _buildToolSection(
              'Document Tools',
              _documentTools.where((t) {
                // Hide OCR and generic PDF tools on web for now
                return !['pdfocr', 'ocr'].contains(t['id']);
              }).toList(),
              isMobile,
            ),
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
    final allTools = [..._documentTools, ..._legalTools, ..._chambersTools];
    final tool = allTools.firstWhere((t) => t['id'] == _activeToolId);
    Widget toolWidget;
    final String title = tool['title'];

    if (tool.containsKey('ext')) {
      /*
      toolWidget = GenericPdfTool(
        toolId: tool['id'],
        title: tool['title'],
        description: tool['desc'],
        icon: tool['icon'],
        allowedExtensions: List<String>.from(tool['ext']),
        targetExtension: tool['target'],
        toolParams: tool['params'],
      );
      */
      toolWidget = const Center(
        child: Text('PDF Tools are currently mobile-only. Check back soon!'),
      );
    } else {
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
        case 'ocr':
          // toolWidget = const OcrTool();
          toolWidget = const Center(
            child: Text('OCR Scanner is currently mobile-only.'),
          );
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
        default:
          toolWidget = Center(child: Text('Tool: $_activeToolId'));
      }
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
