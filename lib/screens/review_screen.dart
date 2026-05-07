import 'dart:io';

import 'package:flutter/material.dart';

import '../models/duplicate_group.dart';
import '../models/photo_item.dart';
import '../utils/formatters.dart';

class ReviewScreen extends StatefulWidget {
  final DuplicateGroup group;
  final bool canDelete;
  final Future<bool> Function(Set<String> selectedIds)? onDeleteSelected;

  const ReviewScreen({
    super.key,
    required this.group,
    this.canDelete = false,
    this.onDeleteSelected,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.group.suggestedDuplicates.map((item) => item.id).toSet();
  }

  Future<void> _cleanSelected() async {
    if (!widget.canDelete || _selectedIds.isEmpty) return;
    final cleaned = await widget.onDeleteSelected?.call(_selectedIds) ?? false;
    if (mounted && cleaned) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final best = widget.group.best;
    final selectedBytes = widget.group.items
        .where((item) => _selectedIds.contains(item.id))
        .fold(0, (sum, item) => sum + item.estimatedBytes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review duplicates'),
        actions: [
          TextButton.icon(
            onPressed: widget.canDelete ? _cleanSelected : null,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clean'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _KeeperCard(best: best, confidence: widget.group.confidence),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.sd_storage_outlined),
              title: Text('${_selectedIds.length} selected for removal'),
              subtitle: Text('${formatBytes(selectedBytes)} estimated reclaimable'),
            ),
          ),
          const SizedBox(height: 16),
          Text('Photos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...widget.group.items.map(
            (item) => _PhotoCard(
              item: item,
              isBest: item.id == best.id,
              selected: _selectedIds.contains(item.id),
              onChanged: item.id == best.id
                  ? null
                  : (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIds.add(item.id);
                        } else {
                          _selectedIds.remove(item.id);
                        }
                      });
                    },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.canDelete ? _cleanSelected : null,
            icon: const Icon(Icons.delete_outline),
            label: Text(widget.canDelete ? 'Delete selected duplicates' : 'Unlock Pro to batch clean'),
          ),
        ],
      ),
    );
  }
}

class _KeeperCard extends StatelessWidget {
  final PhotoItem best;
  final double confidence;

  const _KeeperCard({required this.best, required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _ImageThumb(item: best, size: 74),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recommended keeper', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(best.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${best.width} x ${best.height} - score ${best.qualityScore.toStringAsFixed(0)}'),
                ],
              ),
            ),
            Chip(label: Text(formatPercent(confidence))),
          ],
        ),
      ),
    );
  }
}

class _PhotoCard extends StatelessWidget {
  final PhotoItem item;
  final bool isBest;
  final bool selected;
  final ValueChanged<bool?>? onChanged;

  const _PhotoCard({
    required this.item,
    required this.isBest,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: CheckboxListTile(
        value: isBest ? false : selected,
        onChanged: onChanged,
        secondary: _ImageThumb(item: item, size: 56),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${item.width} x ${item.height} - ${formatBytes(item.estimatedBytes)} - score ${item.qualityScore.toStringAsFixed(0)}',
        ),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final PhotoItem item;
  final double size;

  const _ImageThumb({
    required this.item,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final path = item.filePath;
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _FallbackThumb(size: size),
        ),
      );
    }

    return _FallbackThumb(size: size);
  }
}

class _FallbackThumb extends StatelessWidget {
  final double size;

  const _FallbackThumb({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image_outlined),
    );
  }
}
