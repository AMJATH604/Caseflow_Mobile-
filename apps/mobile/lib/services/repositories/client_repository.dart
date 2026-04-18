import '../../models/models.dart';
import 'base_repository.dart';

/// Repository for client management operations.
class ClientRepository {
  static final _client = BaseRepository.client;

  static Future<List<ClientModel>> fetchClients({int? limit, int? offset}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final profile = await BaseRepository.getCachedProfile();
    final orFilter = BaseRepository.buildVisibilityFilter(
      profile,
      user.id,
      userField: 'created_by',
    );

    var query = _client.from('clients').select().or(orFilter);

    // Apply pagination and ordering in a single chain to avoid type mismatch
    final List response;
    if (limit != null && offset != null) {
      response = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
    } else if (limit != null) {
      response = await query.order('created_at', ascending: false).limit(limit);
    } else {
      response = await query.order('created_at', ascending: false);
    }
    return response
        .map((json) => ClientModel.fromJson(json))
        .toList();
  }

  static Future<ClientModel> createClient(
      Map<String, dynamic> clientData) async {
    final user = BaseRepository.requireAuth();
    final profile = await BaseRepository.getCachedProfile();
    final targetFirmId = BaseRepository.getTargetFirmId(profile, user.id);

    final response = await _client.from('clients').insert({
      ...clientData,
      'created_by': user.id,
      'firm_id': targetFirmId,
    }).select().single();
    return ClientModel.fromJson(response);
  }

  static Future<void> updateClient(
      String id, Map<String, dynamic> updates) async {
    await _client.from('clients').update(updates).eq('id', id);
  }

  static Future<void> deleteClient(String id) async {
    await _client.from('clients').delete().eq('id', id);
  }
}
