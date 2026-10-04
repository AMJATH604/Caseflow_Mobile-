import 'package:supabase_flutter/supabase_flutter.dart';
import 'repositories/base_repository.dart';

/// Model for a legal news article from LiveLaw or other sources.
class LegalNewsArticle {
  final String id;
  final String title;
  final String? summary;
  final String link;
  final String? imageUrl;
  final String category;
  final String source;
  final DateTime? publishedAt;
  final DateTime? createdAt;

  LegalNewsArticle({
    required this.id,
    required this.title,
    this.summary,
    required this.link,
    this.imageUrl,
    required this.category,
    required this.source,
    this.publishedAt,
    this.createdAt,
  });

  factory LegalNewsArticle.fromJson(Map<String, dynamic> json) {
    return LegalNewsArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      link: json['link'] as String,
      imageUrl: json['image_url'] as String?,
      category: json['category'] as String? ?? 'general',
      source: json['source'] as String? ?? 'livelaw',
      publishedAt:
          json['published_at'] != null
              ? DateTime.tryParse(json['published_at'] as String)
              : null,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
    );
  }
}

/// Service for fetching legal news articles and managing bookmarks.
class LegalNewsService {
  static final _client = Supabase.instance.client;

  /// Fetch articles, optionally filtered by category.
  static Future<List<LegalNewsArticle>> fetchArticles({
    String? category,
    int limit = 50,
  }) async {
    var query = _client
        .from('legal_news')
        .select()
        .order('published_at', ascending: false)
        .limit(limit);

    if (category != null && category.isNotEmpty) {
      query = _client
          .from('legal_news')
          .select()
          .eq('category', category)
          .order('published_at', ascending: false)
          .limit(limit);
    }

    final response = await query;
    return (response as List)
        .map((json) => LegalNewsArticle.fromJson(json))
        .toList();
  }

  /// Search articles by keyword in title or summary.
  static Future<List<LegalNewsArticle>> searchArticles(String query) async {
    // sanitizeFilterValue escapes the filter but keeps Tamil; the old
    // [^\w\s] stripped every Tamil letter, leaving %% that matched all rows.
    final sanitized = BaseRepository.sanitizeFilterValue(query);
    if (sanitized.isEmpty) return [];
    final response = await _client
        .from('legal_news')
        .select()
        .or('title.ilike.%$sanitized%,summary.ilike.%$sanitized%')
        .order('published_at', ascending: false)
        .limit(30);
    return (response as List)
        .map((json) => LegalNewsArticle.fromJson(json))
        .toList();
  }

  /// Fetch user's bookmarked articles.
  static Future<List<LegalNewsArticle>> fetchBookmarks() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('legal_news_bookmarks')
        .select('article_id, legal_news(*)')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (response as List).map((row) {
      final articleJson = row['legal_news'] as Map<String, dynamic>;
      return LegalNewsArticle.fromJson(articleJson);
    }).toList();
  }

  /// Add a bookmark for the current user.
  static Future<void> addBookmark(String articleId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('legal_news_bookmarks').upsert({
      'user_id': user.id,
      'article_id': articleId,
    });
  }

  /// Remove a bookmark.
  static Future<void> removeBookmark(String articleId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client
        .from('legal_news_bookmarks')
        .delete()
        .eq('user_id', user.id)
        .eq('article_id', articleId);
  }

  /// Check if an article is bookmarked by the current user.
  static Future<bool> isBookmarked(String articleId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    final response =
        await _client
            .from('legal_news_bookmarks')
            .select('id')
            .eq('user_id', user.id)
            .eq('article_id', articleId)
            .maybeSingle();

    return response != null;
  }

  /// Trigger the Edge Function to fetch fresh articles from RSS.
  static Future<void> triggerFetch() async {
    await _client.functions.invoke('fetch-legal-news');
  }
}
