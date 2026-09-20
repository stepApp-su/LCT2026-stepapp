import 'package:flutter/material.dart';

import '../app_state.dart';

class ShopScreen extends StatelessWidget {
  final AppState appState;

  const ShopScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Магазин подарков')),
          body: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: appState.shopItems.length,
            itemBuilder: (context, index) {
              final item = appState.shopItems[index];
              final owned = appState.progress.purchasedItemIds.contains(item.id);
              final affordable = appState.rules.canAfford(appState.progress, item);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.card_giftcard, size: 40),
                      const SizedBox(height: 8),
                      Text(item.title, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      if (owned)
                        const Chip(label: Text('Куплено'))
                      else
                        FilledButton(
                          onPressed: affordable
                              ? () async {
                                  await appState.purchase(item);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(appState.lineFor('purchase'))),
                                    );
                                  }
                                }
                              : null,
                          child: Text('${item.cost} очков'),
                        ),
                    ],
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
