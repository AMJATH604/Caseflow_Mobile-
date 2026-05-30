import 'package:flutter_test/flutter_test.dart';
import 'package:caseflow/models/models.dart';

/// Tests for the subscription gating logic.
/// Verifies that isPro, isBusiness, isTrialActive, and isSubscriptionActive
/// correctly gate features based on tier + expiration.
void main() {
  group('UserProfile.isPro', () {
    test('free tier without trial is not Pro', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
      });
      expect(profile.isPro, false);
    });

    test('free tier with active trial is Pro', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
        'trial_ends_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });
      expect(profile.isPro, true);
    });

    test('free tier with expired trial is not Pro', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
        'trial_ends_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });
      expect(profile.isPro, false);
    });

    test('pro tier with active subscription is Pro', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'pro',
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(profile.isPro, true);
    });

    test('pro tier with expired subscription is not Pro', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'pro',
        'current_period_end': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });
      expect(profile.isPro, false);
    });

    test('pro tier with expired subscription but active trial is Pro', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'pro',
        'current_period_end': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'trial_ends_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });
      expect(profile.isPro, true);
    });

    test('business tier with active subscription is Pro', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'business',
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(profile.isPro, true);
    });
  });

  group('UserProfile.isBusiness', () {
    test('free tier is never Business', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
        'trial_ends_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });
      expect(profile.isBusiness, false);
    });

    test('pro tier is never Business', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'pro',
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(profile.isBusiness, false);
    });

    test('business tier with active subscription is Business', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'business',
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(profile.isBusiness, true);
    });

    test('business tier with expired subscription is not Business', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'business',
        'current_period_end': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });
      expect(profile.isBusiness, false);
    });
  });

  group('UserProfile.isFree', () {
    test('free tier without trial is Free', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
      });
      expect(profile.isFree, true);
    });

    test('pro tier with active sub is not Free', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'pro',
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });
      expect(profile.isFree, false);
    });
  });

  group('UserProfile.isTrialActive', () {
    test('null trial_ends_at means no trial', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
      });
      expect(profile.isTrialActive, false);
    });

    test('future trial_ends_at means active trial', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
        'trial_ends_at': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      });
      expect(profile.isTrialActive, true);
    });

    test('past trial_ends_at means expired trial', () {
      final profile = UserProfile.fromJson({
        'id': 'user-1',
        'subscription_tier': 'free',
        'trial_ends_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
      });
      expect(profile.isTrialActive, false);
    });
  });
}
