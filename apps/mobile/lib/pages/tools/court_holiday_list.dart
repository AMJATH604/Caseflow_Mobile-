import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CourtHolidayList extends StatelessWidget {
  const CourtHolidayList({super.key});

  @override
  Widget build(BuildContext context) {
    // Static data for 2026 major court holidays (General Indian/TN pattern)
    final List<Map<String, dynamic>> holidays = [
      {
        "month": "January",
        "days": [
          {"name": "New Year's Day", "date": "Jan 1"},
          {"name": "Pongal / Sankranti", "date": "Jan 14-16"},
          {"name": "Republic Day", "date": "Jan 26"},
        ],
      },
      {
        "month": "February",
        "days": [
          {"name": "Maha Shivaratri", "date": "Feb 15"},
        ],
      },
      {
        "month": "March",
        "days": [
          {"name": "Holi", "date": "Mar 4"},
          {"name": "Eid-ul-Fitr (Approx)", "date": "Mar 31"},
        ],
      },
      {
        "month": "April",
        "days": [
          {"name": "Good Friday", "date": "Apr 3"},
          {"name": "Tamil New Year / Vishu", "date": "Apr 14"},
        ],
      },
      {
        "month": "May",
        "days": [
          {
            "name": "Summer Vacation",
            "date": "May 1 - May 31",
            "type": "vacation",
          },
        ],
      },
      {
        "month": "August",
        "days": [
          {"name": "Independence Day", "date": "Aug 15"},
        ],
      },
      {
        "month": "October",
        "days": [
          {"name": "Gandhi Jayanti", "date": "Oct 2"},
          {"name": "Vijayadashami / Dussehra", "date": "Oct 21"},
        ],
      },
      {
        "month": "November",
        "days": [
          {"name": "Diwali / Deepavali", "date": "Nov 8"},
        ],
      },
      {
        "month": "December",
        "days": [
          {
            "name": "Winter Vacation",
            "date": "Dec 24 - Dec 31",
            "type": "vacation",
          },
        ],
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        itemCount: holidays.length,
        itemBuilder: (context, index) {
          final month = holidays[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 8,
                ),
                child: Text(
                  month['month'].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppTheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              ...((month['days'] as List).map((day) => _buildHolidayCard(day))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHolidayCard(Map<String, dynamic> day) {
    final isVacation = day['type'] == 'vacation';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isVacation ? Colors.orange.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isVacation
                  ? Colors.orange.withValues(alpha: 0.2)
                  : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isVacation
                      ? Colors.orange.withValues(alpha: 0.1)
                      : AppTheme.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVacation
                  ? Icons.beach_access_rounded
                  : Icons.event_available_rounded,
              color: isVacation ? Colors.orange : AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  isVacation ? "Court Vacation" : "Public Holiday",
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            day['date'],
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
