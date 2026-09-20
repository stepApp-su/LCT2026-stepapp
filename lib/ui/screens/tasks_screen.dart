import 'package:flutter/material.dart';

import '../app_state.dart';

class TasksScreen extends StatelessWidget {
  final AppState appState;

  const TasksScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Задания')),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: appState.tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final task = appState.tasks[index];
              final done = appState.rules.isTaskCompleted(appState.progress, task);
              return Card(
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text(task.description),
                  trailing: done
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : TextButton(
                          onPressed: () async {
                            await appState.completeTask(task);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(appState.lineFor('task_completed'))),
                              );
                            }
                          },
                          child: Text('+${task.reward}'),
                        ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
