import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized analytics service for tracking feature usage across CaseFlow.
///
/// Usage:
///   AnalyticsService.logScreenView('Dashboard');
///   AnalyticsService.logFeatureUsed('limitation_calculator');
///   AnalyticsService.logEvent('case_created', {'case_type': 'civil'});
class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Observer for automatic screen tracking with GoRouter.
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ─── Screen Tracking ───────────────────────────────────

  /// Log when a user views a screen.
  static Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('Analytics: Failed to log screen view: $e');
    }
  }

  // ─── Feature Usage ─────────────────────────────────────

  /// Log when a user uses a specific feature/tool.
  static Future<void> logFeatureUsed(
    String featureName, {
    Map<String, Object>? params,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'feature_used',
        parameters: {'feature_name': featureName, ...?params},
      );
    } catch (e) {
      debugPrint('Analytics: Failed to log feature usage: $e');
    }
  }

  // ─── Custom Events ─────────────────────────────────────

  /// Log a custom event with optional parameters.
  static Future<void> logEvent(
    String name, [
    Map<String, Object>? params,
  ]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics: Failed to log event: $e');
    }
  }

  // ─── User Properties ───────────────────────────────────

  /// Set a user property (e.g., user role, firm type).
  static Future<void> setUserProperty(String name, String value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      debugPrint('Analytics: Failed to set user property: $e');
    }
  }

  /// Set the user ID for analytics (call on login).
  static Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('Analytics: Failed to set user ID: $e');
    }
  }

  // ─── Pre-built Legal Events ────────────────────────────

  static Future<void> logCaseCreated(String caseType) =>
      logEvent('case_created', {'case_type': caseType});

  static Future<void> logCaseViewed(String caseId) =>
      logEvent('case_viewed', {'case_id': caseId});

  static Future<void> logHearingAdded(String caseId) =>
      logEvent('hearing_added', {'case_id': caseId});

  static Future<void> logDocumentUploaded(String docType) =>
      logEvent('document_uploaded', {'doc_type': docType});

  static Future<void> logAIQuerySent({bool hasAttachment = false}) =>
      logEvent('ai_query_sent', {'has_attachment': hasAttachment.toString()});

  static Future<void> logToolUsed(String toolName) =>
      logFeatureUsed(toolName, params: {'category': 'tool'});

  static Future<void> logPortalAccessed(
    String state,
    String district,
    String type,
  ) => logEvent('portal_accessed', {
    'state': state,
    'district': district,
    'portal_type': type,
  });

  static Future<void> logChamberMessageSent({bool hasAttachment = false}) =>
      logEvent('chamber_message_sent', {
        'has_attachment': hasAttachment.toString(),
      });

  static Future<void> logBareActViewed(String actName) =>
      logEvent('bare_act_viewed', {'act_name': actName});

  static Future<void> logSearchPerformed(String query) =>
      logEvent('search_performed', {'query_length': query.length.toString()});
}
