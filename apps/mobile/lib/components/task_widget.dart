import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/providers.dart';
import '../theme/app_theme.dart';

class TaskWidget extends ConsumerWidget {
  const TaskWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Daily Tasks",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent),
                onPressed: () {
                  _showAddTaskDialog(context, ref);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No tasks for today", style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              return Column(
                children: tasks.map((task) => _buildTaskItem(task, ref)).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Column(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.grey, size: 32),
                const SizedBox(height: 8),
                const Text(
                  "Unable to load tasks",
                  style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => ref.invalidate(tasksProvider),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("Tap to Retry"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(TaskModel task, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Checkbox(
            value: task.isCompleted,
            activeColor: AppTheme.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) async {
              await SupabaseService.updateTask(task.id, {'is_completed': val});
              ref.invalidate(tasksProvider);
            },
          ),
          Expanded(
            child: Text(
              task.title,
              style: TextStyle(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? Colors.grey : AppTheme.primary,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
            onPressed: () async {
              await SupabaseService.deleteTask(task.id);
              ref.invalidate(tasksProvider);
            },
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New Task"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter task title"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await SupabaseService.createTask(controller.text);
                ref.invalidate(tasksProvider);
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }
}
