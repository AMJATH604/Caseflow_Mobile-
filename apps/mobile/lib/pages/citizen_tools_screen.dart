import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../components/epay_court_fee_sheet.dart';
import 'tools/court_fee_calculator.dart';
import 'tools/interest_calculator.dart';
import 'tools/delay_calculator.dart';
import 'tools/limitation_calculator.dart';
import 'tools/bare_acts_screen.dart';
import 'tools/court_holiday_list.dart';
import 'tools/legal_templates_screen.dart';
import 'tools/stamp_value_screen.dart';
import 'tools/partition_calculator.dart';
import 'tools/mact_calculator.dart';
import 'tools/maintenance_calculator.dart';
import 'tools/legal_dictionary.dart';
import 'tools/english_dictionary.dart';

class CitizenToolsScreen extends ConsumerStatefulWidget {
  final String? initialToolId;
  const CitizenToolsScreen({super.key, this.initialToolId});

  @override
  ConsumerState<CitizenToolsScreen> createState() => _CitizenToolsScreenState();
}

class _CitizenToolsScreenState extends ConsumerState<CitizenToolsScreen> {
  String? _activeToolId;

  final List<Map<String, dynamic>> _calculatorTools = [
    {
      'id': 'court-fee',
      'title': 'Court Fee',
      'desc': 'Calculate court fees',
      'icon': Icons.calculate,
      'color': Colors.orange,
    },
    {
      'id': 'epay_court_fee',
      'title': 'eCourts ePay',
      'desc': 'Pay court fees online',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFF2563EB),
    },
    {
      'id': 'interest',
      'title': 'Interest',
      'desc': 'Calculate interest',
      'icon': Icons.percent,
      'color': Colors.purple,
    },
    {
      'id': 'delay',
      'title': 'Delay (Sec 5)',
      'desc': 'Calculate delay period',
      'icon': Icons.schedule,
      'color': Colors.red,
    },
    {
      'id': 'limitation',
      'title': 'Limitation',
      'desc': 'Track deadlines',
      'icon': Icons.timer,
      'color': Colors.teal,
    },
    {
      'id': 'partition_calculator',
      'title': 'Partition Share',
      'desc': 'Hindu & Muslim Law',
      'icon': Icons.family_restroom,
      'color': Colors.pink,
    },
    {
      'id': 'mact_calculator',
      'title': 'MACT Claims',
      'desc': 'Accident compensation',
      'icon': Icons.directions_car,
      'color': Colors.red,
    },
    {
      'id': 'maintenance_calculator',
      'title': 'Maintenance',
      'desc': 'Sec 144 BNSS / HAMA',
      'icon': Icons.account_balance_wallet,
      'color': Colors.deepPurple,
    },
    {
      'id': 'stamp_values',
      'title': 'Stamp Values',
      'desc': 'Petition stamp reference',
      'icon': Icons.receipt_long_rounded,
      'color': Colors.amber,
    },
  ];

  final List<Map<String, dynamic>> _libraryTools = [
    {
      'id': 'bare_acts',
      'title': 'Bare Acts Library',
      'desc': 'BNS, BNSS, CPC & more',
      'icon': Icons.library_books,
      'color': Colors.brown,
    },
    {
      'id': 'legal_dictionary',
      'title': 'Legal Dictionary',
      'desc': '500+ Latin & Legal terms',
      'icon': Icons.import_contacts_rounded,
      'color': Colors.orange,
    },
    {
      'id': 'english_dictionary',
      'title': 'English Dictionary',
      'desc': 'Curated A-Z vocabulary',
      'icon': Icons.spellcheck_rounded,
      'color': Colors.teal,
    },
    {
      'id': 'legal_templates',
      'title': 'Legal Templates',
      'desc': 'PDF & Word drafts',
      'icon': Icons.description_rounded,
      'color': const Color(0xFFD4AF37),
    },
    {
      'id': 'holiday_list',
      'title': 'Court Holidays',
      'desc': 'Court holidays 2026',
      'icon': Icons.calendar_month_rounded,
      'color': Colors.deepOrange,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialToolId != null && widget.initialToolId!.isNotEmpty) {
      _activeToolId = widget.initialToolId;
    }
  }

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
                  'Legal Toolkit',
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(fontSize: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  'Essential legal tools for every Indian citizen',
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
          _buildToolSection('Calculators', _calculatorTools, isMobile),
          const SizedBox(height: 20),
          _buildToolSection('Legal Library', _libraryTools, isMobile),
          const SizedBox(height: 100),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) => _buildToolCard(tools[index]),
        ),
      ],
    );
  }

  Widget _buildToolCard(Map<String, dynamic> tool) {
    return InkWell(
      onTap: () => _onToolTap(tool),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: AppTheme.cardDecoration(
          isDark: Theme.of(context).brightness == Brightness.dark,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (tool['color'] as Color).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (tool['color'] as Color).withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(tool['icon'], color: tool['color'], size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                tool['title'],
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  tool['desc'].toString().toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 8,
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
      ),
    );
  }

  void _onToolTap(Map<String, dynamic> tool) {
    if (tool['id'] == 'epay_court_fee') {
      EPayCourtFeeSheet.show(context);
    } else {
      setState(() => _activeToolId = tool['id']);
    }
  }

  Widget _buildToolView() {
    final allTools = [..._calculatorTools, ..._libraryTools];
    final tool = allTools.firstWhere(
      (t) => t['id'] == _activeToolId,
      orElse: () => allTools.first,
    );
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

    final isMobile = MediaQuery.of(context).size.width < 768;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              const SizedBox(width: 12),
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
        const SizedBox(height: 16),
        Expanded(child: toolWidget),
      ],
    );
  }
}
