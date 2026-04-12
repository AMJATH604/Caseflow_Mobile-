import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/providers.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class BroadcastNode extends ConsumerStatefulWidget {
  const BroadcastNode({super.key});

  @override
  ConsumerState<BroadcastNode> createState() => _BroadcastNodeState();
}

class _BroadcastNodeState extends ConsumerState<BroadcastNode> {
  final _noticeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<CaseComment> _optimisticNotices = [];
  final List<String> _deletedIds = [];
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _noticeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.fetchProfile();
    if (mounted) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) return const Center(child: CircularProgressIndicator());

    return _buildNoticeBoard();
  }




  Widget _buildNoticeBoard() {
    final firmId = _profile?.firmId ?? _profile?.id;
    if (firmId == null) return const Center(child: Text("No firm connection"));
    final noticesAsync = ref.watch(firmNoticesProvider(firmId));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.grey),
      ),
      child: Column(
        children: [
          Expanded(
            child: noticesAsync.when(
              data: (streamNotices) {
                // Passive Clock Sync: Use the latest server message to adjust our local offset
                if (streamNotices.isNotEmpty) {
                  SupabaseService.updateOffset(streamNotices.last.createdAt);
                }

                final pendingOptimistic = _optimisticNotices.where(
                  (opt) => !streamNotices.any((s) => s.message == opt.message && s.senderId == opt.senderId),
                ).toList();

                final allNotices = [...streamNotices, ...pendingOptimistic]
                    .where((n) => !_deletedIds.contains(n.id))
                    .toList();
                
                // Absolute explicit sorting (Oldest to Newest)
                allNotices.sort((a, b) => a.createdAt.compareTo(b.createdAt));

                if (allNotices.isEmpty) {
                  return const Center(child: Text("No broadcasts found.", style: TextStyle(color: Colors.grey, fontSize: 12)));
                }

                // Auto-scroll to bottom after render
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: false, // Natural top-to-bottom
                  padding: const EdgeInsets.all(16),
                  itemCount: allNotices.length,
                  itemBuilder: (context, index) {
                    final msg = allNotices[index];
                    final isMe = msg.senderId == _profile?.id;
                    return _buildNoticeBubble(msg, isMe);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Connection error: $e")),
            ),
          ),
          _buildInputArea(firmId),
        ],
      ),
    );
  }

  Widget _buildNoticeBubble(CaseComment msg, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          if (isMe) {
            _showDeleteDialog(msg);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 240),
          decoration: BoxDecoration(
            color: isMe ? AppTheme.accent : (isDark ? const Color(0xFFE2E8F0) : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Text(msg.senderName ?? "Team Member", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.accent.withValues(alpha: 0.8))),
              Text(msg.message, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black), fontSize: 13, fontWeight: isMe ? FontWeight.w600 : FontWeight.w400)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('HH:mm').format(msg.createdAt.toIST()), 
                    style: TextStyle(fontSize: 8, color: (isMe ? Colors.white : (isDark ? Colors.white : Colors.black)).withValues(alpha: 0.4))
                  ),
                  if (msg.id.startsWith('temp'))
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.access_time_rounded, size: 8, color: isMe ? Colors.white70 : Colors.grey),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(CaseComment msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete message?"),
        content: const Text("This message will be removed for everyone in the team."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (msg.id.startsWith('temp')) {
                 setState(() {
                   _optimisticNotices.removeWhere((m) => m.id == msg.id);
                 });
                 return;
              }
              
              // Optimistic deletion
              setState(() {
                 _deletedIds.add(msg.id);
              });
              
              final messenger = ScaffoldMessenger.of(context);
              try {
                await SupabaseService.deleteDiscussion(msg.id);
              } catch (e) {
                if (mounted) {
                   setState(() => _deletedIds.remove(msg.id));
                   messenger.showSnackBar(SnackBar(content: Text("Delete failed: $e")));
                }
              }
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(String firmId) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.02),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _noticeController,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(hintText: "Broadcast to firm...", border: InputBorder.none, filled: false),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppTheme.accent),
            onPressed: () async {
              final text = _noticeController.text.trim();
              if (text.isEmpty) return;
              final senderName = _profile?.fullName ?? "Team Member";
              
              // Optimistic update FIRST
              final optimisticMsg = CaseComment(
                id: 'temp_${DateTime.now().millisecondsSinceEpoch}', 
                firmId: firmId, 
                senderId: _profile?.id ?? '', 
                message: text, 
                senderName: senderName, 
                createdAt: SupabaseService.syncedNow
              );
              
              setState(() {
                _optimisticNotices.add(optimisticMsg);
              });
              _noticeController.clear();

              try {
                await SupabaseService.postDiscussion({
                  'firm_id': firmId, 
                  'message': text, 
                  'case_id': null, 
                  'sender_name': senderName
                });
              } catch (e) {
                // Remove on failure
                setState(() {
                  _optimisticNotices.removeWhere((m) => m.id == optimisticMsg.id);
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to send: $e"))
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
