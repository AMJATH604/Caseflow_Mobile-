import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/models/models.dart';

/// Unit tests for all model classes.
/// Tests fromJson() deserialization and critical getters.
void main() {
  group('UserProfile', () {
    test('fromJson creates profile with all fields', () {
      final json = {
        'id': 'user-123',
        'full_name': 'Advocate Kumar',
        'subscription_tier': 'pro',
        'trial_ends_at': '2026-12-31T23:59:59Z',
        'current_period_end': '2026-12-31T23:59:59Z',
        'firm_id': null,
        'email': 'kumar@law.com',
        'mobile_number': '9876543210',
        'registration_number': 'BAR/TN/2020/001',
        'practice_state': 'Tamil Nadu',
        'practice_district': 'Chennai',
        'office_address': 'High Court Campus',
        'is_public_directory_enabled': true,
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.fullName, 'Advocate Kumar');
      expect(profile.subscriptionTier, 'pro');
      expect(profile.email, 'kumar@law.com');
      expect(profile.practiceState, 'Tamil Nadu');
    });

    test('isPro returns true for pro tier with active subscription', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'pro',
        'current_period_end': '2099-12-31T23:59:59Z',
      });
      expect(profile.isPro, true);
    });

    test('isPro returns false for expired subscription', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'pro',
        'current_period_end': '2020-01-01T00:00:00Z',
      });
      expect(profile.isPro, false);
    });

    test('isPro returns true during trial period', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
        'trial_ends_at': '2099-12-31T23:59:59Z',
      });
      expect(profile.isPro, true);
    });

    test('isPro returns false for free tier with no trial', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
      });
      expect(profile.isPro, false);
    });

    test('isBusiness returns true only for business tier', () {
      final pro = UserProfile.fromJson({
        'id': 'u1',
        'subscription_tier': 'pro',
        'current_period_end': '2099-12-31T23:59:59Z',
      });
      final biz = UserProfile.fromJson({
        'id': 'u2',
        'subscription_tier': 'business',
        'current_period_end': '2099-12-31T23:59:59Z',
      });
      expect(pro.isBusiness, false);
      expect(biz.isBusiness, true);
    });

    test('isFirmOwner is true when firmId is null', () {
      final owner = UserProfile.fromJson({'id': 'u1', 'firm_id': null});
      final member = UserProfile.fromJson({'id': 'u2', 'firm_id': 'firm-1'});
      expect(owner.isFirmOwner, true);
      expect(member.isFirmOwner, false);
    });

    test('toJson serializes correctly', () {
      final profile = UserProfile.fromJson({
        'id': 'user-123',
        'full_name': 'Test User',
        'subscription_tier': 'free',
      });
      final json = profile.toJson();
      expect(json['id'], 'user-123');
      expect(json['full_name'], 'Test User');
      expect(json['subscription_tier'], 'free');
    });

    test('fromJson handles null/missing fields gracefully', () {
      final profile = UserProfile.fromJson({'id': 'minimal'});
      expect(profile.id, 'minimal');
      expect(profile.fullName, isNull);
      expect(profile.subscriptionTier, 'free');
      expect(profile.firmId, isNull);
      expect(profile.isPro, false);
    });
  });

  group('CaseModel', () {
    test('fromJson creates case with essential fields', () {
      final json = {
        'id': 'case-001',
        'case_title': 'Kumar vs State of TN',
        'case_number': 'OS/123/2025',
        'status': 'active',
        'stage': 'Arguments',
        'court_type': 'district',
        'created_by': 'user-1',
      };
      final c = CaseModel.fromJson(json);
      expect(c.id, 'case-001');
      expect(c.caseTitle, 'Kumar vs State of TN');
      expect(c.caseNumber, 'OS/123/2025');
    });
  });

  group('Hearing', () {
    test('fromJson parses hearing with case data', () {
      final json = {
        'id': 'h-001',
        'case_id': 'case-001',
        'hearing_date': '2026-05-15',
        'stage': 'Arguments',
        'status': 'scheduled',
        'created_by': 'user-1',
        'cases': {
          'case_title': 'Test Case',
          'court_name': 'Madras HC',
          'case_number': 'OS/1/2025',
        },
      };
      final h = Hearing.fromJson(json);
      expect(h.id, 'h-001');
      expect(h.hearingDate, isA<DateTime>());
    });
  });

  group('Payment', () {
    test('fromJson handles payment with amounts', () {
      final json = {
        'id': 'p-001',
        'case_id': 'case-001',
        'total_fee': 50000,
        'paid_amount': 25000,
        'balance_amount': 25000,
        'paid_date': '2026-04-01',
        'created_by': 'user-1',
      };
      final p = Payment.fromJson(json);
      expect(p.id, 'p-001');
      expect(p.totalFee, 50000);
    });
  });

  group('EFilingRecord', () {
    test('fromJson parses efiling status', () {
      final json = {
        'id': 'ef-001',
        'case_id': 'case-001',
        'status': 'filed',
        'filing_date': '2026-04-10',
        'created_by': 'user-1',
      };
      final ef = EFilingRecord.fromJson(json);
      expect(ef.id, 'ef-001');
      expect(ef.status, FilingStatus.filed);
    });
  });

  group('TaskModel', () {
    test('fromJson creates task', () {
      final json = {
        'id': 'task-001',
        'title': 'File rejoinder',
        'is_completed': false,
        'created_by': 'user-1',
        'created_at': '2026-04-15T10:00:00Z',
      };
      final t = TaskModel.fromJson(json);
      expect(t.id, 'task-001');
      expect(t.title, 'File rejoinder');
    });
  });

  group('LegalTemplate', () {
    test('fromJson parses template', () {
      final json = {
        'id': 'lt-001',
        'title': 'Bail Application',
        'category': 'Criminal',
        'description': 'Standard bail application format',
        'content': 'IN THE COURT OF...',
      };
      final t = LegalTemplate.fromJson(json);
      expect(t.id, 'lt-001');
      expect(t.title, 'Bail Application');
    });
  });

  group('CaseComment', () {
    test('fromJson parses discussion message', () {
      final json = {
        'id': 'cc-001',
        'case_id': 'case-001',
        'sender_id': 'user-1',
        'message': 'Filed the written statement today',
        'created_at': '2026-04-15T10:00:00Z',
      };
      final cc = CaseComment.fromJson(json);
      expect(cc.id, 'cc-001');
      expect(cc.message, 'Filed the written statement today');
    });
  });
}
