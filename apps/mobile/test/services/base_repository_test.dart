import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/services/repositories/base_repository.dart';
import 'package:caseflow/models/models.dart';

/// Unit tests for BaseRepository shared utilities.
/// Tests profile caching, visibility filter building, and date normalization.
void main() {
  group('BaseRepository.normalizeDateStr', () {
    test('returns null for null input', () {
      expect(BaseRepository.normalizeDateStr(null), isNull);
    });

    test('returns null for empty string', () {
      expect(BaseRepository.normalizeDateStr(''), isNull);
    });

    test('returns null for whitespace', () {
      expect(BaseRepository.normalizeDateStr('   '), isNull);
    });

    test('passes through already-formatted YYYY-MM-DD', () {
      expect(BaseRepository.normalizeDateStr('2026-04-15'), '2026-04-15');
    });

    test('converts DD-MM-YYYY to YYYY-MM-DD', () {
      expect(BaseRepository.normalizeDateStr('15-04-2026'), '2026-04-15');
    });

    test('converts DD/MM/YYYY to YYYY-MM-DD', () {
      expect(BaseRepository.normalizeDateStr('15/04/2026'), '2026-04-15');
    });

    test('handles leading/trailing whitespace', () {
      expect(BaseRepository.normalizeDateStr('  15-04-2026  '), '2026-04-15');
    });

    test('returns null for unrecognized format', () {
      expect(BaseRepository.normalizeDateStr('April 15, 2026'), isNull);
    });

    test('handles 01-01-2025 edge case', () {
      expect(BaseRepository.normalizeDateStr('01-01-2025'), '2025-01-01');
    });

    test('handles 31/12/2025 edge case', () {
      expect(BaseRepository.normalizeDateStr('31/12/2025'), '2025-12-31');
    });

    // ── Formats that reach us from imports ──
    // A null here is not cosmetic: the eCourts importer skips hearing
    // creation when the date will not parse, which is what left imported
    // cases with an empty Court Diary.

    test('drops the time part of an ISO-8601 timestamp', () {
      // CaseFlow's own backup files store dates via toIso8601String().
      expect(
        BaseRepository.normalizeDateStr('2026-01-30T00:00:00.000'),
        '2026-01-30',
      );
      expect(
        BaseRepository.normalizeDateStr('2026-01-30T14:22:05.123Z'),
        '2026-01-30',
      );
    });

    test('handles a space-separated timestamp', () {
      expect(
        BaseRepository.normalizeDateStr('2026-01-30 14:22:05'),
        '2026-01-30',
      );
    });

    test('accepts single-digit day and month from eCourts', () {
      expect(BaseRepository.normalizeDateStr('5-4-2026'), '2026-04-05');
      expect(BaseRepository.normalizeDateStr('5/4/2026'), '2026-04-05');
    });

    test('every accepted output is parseable by DateTime.parse', () {
      const inputs = [
        '2026-04-15',
        '15-04-2026',
        '15/04/2026',
        '5-4-2026',
        '2026-01-30T14:22:05.123Z',
        '2026-01-30 14:22:05',
      ];
      for (final input in inputs) {
        final normalized = BaseRepository.normalizeDateStr(input);
        expect(normalized, isNotNull, reason: 'failed to normalize "$input"');
        expect(
          () => DateTime.parse(normalized!),
          returnsNormally,
          reason: '"$input" normalized to unparseable "$normalized"',
        );
      }
    });
  });

  group('BaseRepository.buildVisibilityFilter', () {
    test('solo user gets only own records', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'firm_id': null,
      });
      final filter = BaseRepository.buildVisibilityFilter(profile, 'user-1');
      // Solo user is firm owner (firmId == null), so they should get
      // their own records AND records where firm_id matches their userId
      expect(filter, contains('assigned_to.eq.user-1'));
      expect(filter, contains('firm_id.eq.user-1'));
    });

    test('firm member gets own + firm records', () {
      final profile = UserProfile.fromJson({
        'id': 'member-1',
        'firm_id': 'owner-1',
      });
      final filter =
          BaseRepository.buildVisibilityFilter(profile, 'member-1');
      expect(filter, contains('assigned_to.eq.member-1'));
      expect(filter, contains('firm_id.eq.owner-1'));
    });

    test('custom userField is used', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'firm_id': null,
      });
      final filter = BaseRepository.buildVisibilityFilter(
        profile,
        'user-1',
        userField: 'created_by',
      );
      expect(filter, contains('created_by.eq.user-1'));
    });
  });

  group('BaseRepository.getTargetFirmId', () {
    test('returns firmId for firm member', () {
      final member = UserProfile.fromJson({
        'id': 'member-1',
        'firm_id': 'owner-1',
      });
      expect(BaseRepository.getTargetFirmId(member, 'member-1'), 'owner-1');
    });

    test('returns userId for solo user', () {
      final solo = UserProfile.fromJson({
        'id': 'user-1',
        'firm_id': null,
      });
      expect(BaseRepository.getTargetFirmId(solo, 'user-1'), 'user-1');
    });
  });

  group('BaseRepository.profileCache', () {
    test('invalidateProfileCache clears cache without error', () {
      // Should not throw even when cache is already empty
      BaseRepository.invalidateProfileCache();
      BaseRepository.invalidateProfileCache();
    });
  });

  group('BaseRepository.syncedNow', () {
    test('returns a DateTime close to now', () {
      final now = DateTime.now();
      final synced = BaseRepository.syncedNow;
      expect(synced.difference(now).abs().inSeconds, lessThan(5));
    });

    test('updateOffset adjusts syncedNow', () {
      // Simulate server being 10 seconds ahead
      final serverTime = DateTime.now().toUtc().add(const Duration(seconds: 10));
      BaseRepository.updateOffset(serverTime);
      final synced = BaseRepository.syncedNow;
      final diff = synced.difference(DateTime.now()).inSeconds;
      expect(diff, greaterThanOrEqualTo(8)); // Within 2s tolerance
      expect(diff, lessThanOrEqualTo(12));

      // Reset
      BaseRepository.updateOffset(DateTime.now().toUtc());
    });
  });

  group('BaseRepository.validateRequired', () {
    test('passes when all required fields are present', () {
      expect(
        () => BaseRepository.validateRequired(
          {'name': 'John', 'email': 'john@test.com'},
          ['name', 'email'],
        ),
        returnsNormally,
      );
    });

    test('throws when a required field is missing', () {
      expect(
        () => BaseRepository.validateRequired(
          {'name': 'John'},
          ['name', 'email'],
        ),
        throwsArgumentError,
      );
    });

    test('throws when a required field is empty string', () {
      expect(
        () => BaseRepository.validateRequired(
          {'name': 'John', 'email': '  '},
          ['name', 'email'],
        ),
        throwsArgumentError,
      );
    });

    test('throws when a required field is null', () {
      expect(
        () => BaseRepository.validateRequired(
          {'name': 'John', 'email': null},
          ['name', 'email'],
        ),
        throwsArgumentError,
      );
    });
  });

  group('BaseRepository.validateStringLength', () {
    test('returns null for null input', () {
      expect(
        BaseRepository.validateStringLength(null, 'test'),
        isNull,
      );
    });

    test('returns trimmed value for valid input', () {
      expect(
        BaseRepository.validateStringLength('  hello  ', 'test'),
        'hello',
      );
    });

    test('throws for input exceeding max length', () {
      expect(
        () => BaseRepository.validateStringLength(
          'a' * 501,
          'test',
          maxLength: 500,
        ),
        throwsArgumentError,
      );
    });

    test('passes for input at exactly max length', () {
      expect(
        () => BaseRepository.validateStringLength(
          'a' * 500,
          'test',
          maxLength: 500,
        ),
        returnsNormally,
      );
    });
  });

  group('BaseRepository.sanitizeFilterValue', () {
    test('passes through an ordinary search term', () {
      expect(BaseRepository.sanitizeFilterValue('Kumar'), 'Kumar');
    });

    test('strips commas that would inject an extra PostgREST filter term', () {
      // The attack: a comma ends the ilike term and opens a new OR clause,
      // widening results to rows the user may not be permitted to see.
      final result = BaseRepository.sanitizeFilterValue(
        'x,firm_id.eq.00000000-0000-0000-0000-000000000000',
      );
      expect(result, isNot(contains(',')));
      expect(result, isNot(contains('.')));
    });

    test('strips parentheses used for filter grouping', () {
      final result = BaseRepository.sanitizeFilterValue('a)or(b');
      expect(result, isNot(contains('(')));
      expect(result, isNot(contains(')')));
    });

    test('strips LIKE wildcards so they match literally', () {
      final result = BaseRepository.sanitizeFilterValue('%%%_%');
      expect(result, isNot(contains('%')));
      expect(result, isNot(contains('_')));
    });

    test('collapses whitespace left behind by stripping', () {
      expect(BaseRepository.sanitizeFilterValue('a,,,b'), 'a b');
    });

    test('truncates overlong input to the default max', () {
      expect(BaseRepository.sanitizeFilterValue('a' * 500).length, 100);
    });

    test('respects a custom max length', () {
      expect(
        BaseRepository.sanitizeFilterValue('a' * 50, maxLength: 10).length,
        10,
      );
    });

    test('returns empty when input is only structural characters', () {
      expect(BaseRepository.sanitizeFilterValue(',,,()...'), '');
    });
  });
}
