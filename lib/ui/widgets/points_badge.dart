import 'package:flutter/material.dart';

class PointsBadge extends StatelessWidget {
  final int points;

  const PointsBadge({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 18),
          const SizedBox(width: 6),
          Text('$points', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
