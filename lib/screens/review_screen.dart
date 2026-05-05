import 'dart:io';
import 'package:flutter/material.dart';
import '../models/duplicate_group.dart';
import '../models/photo_item.dart';

class ReviewScreen extends StatelessWidget {
  final DuplicateGroup group;

  const ReviewScreen({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final best = group.best;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Group'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Recommended keeper',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: _ImageThumb(item: best),
              title: Text(best.title),
              subtitle: Text(
                '${best.width} × ${best.height}\nScore: ${best.qualityScore.toStringAsFixed(0)}',
              ),
              trailing: const Chip(label: Text('KEEP')),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'All photos in this group',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...group.items.map(
            (item) => _PhotoCard(
              item: item,
              bestId: best.id,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final PhotoItem item;
  final String bestId;

  const _PhotoCard({
    required this.item,
    required this.bestId,
  });

  @override
  Widget build(BuildContext context) {
    final isBest = item.id == bestId;

    return Card(
      child: ListTile(
        leading: _ImageThumb(item: item),
        title: Text(item.title),
        subtitle: Text(
          '${item.width} × ${item.height} • score ${item.qualityScore.toStringAsFixed(0)}',
        ),
        trailing: isBest
            ? const Chip(label: Text('KEEP'))
            : const Chip(label: Text('DUPLICATE')),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final PhotoItem item;

  const _ImageThumb({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    if (item.filePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(item.filePath!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined),
    );
  }
}