import 'package:flutter/material.dart';

import '../app_state.dart';
import '../widgets/finni_avatar.dart';
import '../widgets/points_badge.dart';
import 'shop_screen.dart';
import 'tasks_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppState appState;

  const HomeScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Питомец Финни'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: PointsBadge(points: appState.progress.points)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const FinniAvatar(),
              const SizedBox(height: 12),
              Text(
                appState.lineFor('welcome'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Звание: ${appState.currentRank.title}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Column(
                  children: [
                    _MenuButton(
                      icon: Icons.checklist_rtl,
                      label: 'Задания',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TasksScreen(appState: appState),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MenuButton(
                      icon: Icons.storefront,
                      label: 'Магазин подарков',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ShopScreen(appState: appState),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
