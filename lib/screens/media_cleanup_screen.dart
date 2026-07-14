import 'dart:io';

import 'package:flutter/material.dart';

import '../models/photo_item.dart';
import '../models/scan_summary.dart';
import '../utils/formatters.dart';

class MediaCleanupScreen extends StatefulWidget {
  final CleanupMode mode;
  final List<PhotoItem> items;
  final bool canDelete;
  final Future<bool> Function(Set<String> selectedIds) onDeleteSelected;

  const MediaCleanupScreen({
    super.key,
    required this.mode,
    required this.items,
    required this.canDelete,
    required this.onDeleteSelected,
  });

  @override
  State<MediaCleanupScreen> createState() => _MediaCleanupScreenState();
}

class _MediaCleanupScreenState extends State<MediaCleanupScreen> {
  final Set<String> _selectedIds = {};

  String get _title => widget.mode == CleanupMode.screenshots
      ? 'Review screenshots'
      : 'Review large photos';

  Future<void> _deleteSelected() async {
    if (!widget.canDelete || _selectedIds.isEmpty) return;
    final deleted = await widget.onDeleteSelected(_selectedIds);
    if (mounted && deleted) Navigator.pop(context);
  }

  void _toggle(PhotoItem item) {
    setState(() {
      if (!_selectedIds.add(item.id)) _selectedIds.remove(item.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedBytes = widget.items
        .where((item) => _selectedIds.contains(item.id))
        .fold<int>(0, (sum, item) => sum + item.estimatedBytes);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: _selectedIds.length == widget.items.length
                ? 'Clear selection'
                : 'Select all',
            onPressed: () {
              setState(() {
                if (_selectedIds.length == widget.items.length) {
                  _selectedIds.clear();
                } else {
                  _selectedIds
                    ..clear()
                    ..addAll(widget.items.map((item) => item.id));
                }
              });
            },
            icon: Icon(_selectedIds.length == widget.items.length
                ? Icons.deselect
                : Icons.select_all),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _SelectionSummary(
                count: _selectedIds.length,
                bytes: selectedBytes,
                mode: widget.mode,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 112),
              sliver: SliverGrid.builder(
                itemCount: widget.items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return _CandidateTile(
                    item: item,
                    selected: _selectedIds.contains(item.id),
                    onSelect: () => _toggle(item),
                    onZoom: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => _InspectPhotoScreen(item: item),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: widget.canDelete && _selectedIds.isNotEmpty
              ? _deleteSelected
              : null,
          icon: const Icon(Icons.delete_outline),
          label: Text(widget.canDelete
              ? _selectedIds.isEmpty
                  ? 'Select photos to remove'
                  : 'Remove ${_selectedIds.length} · ${formatBytes(selectedBytes)}'
              : 'Pro required for cleanup'),
        ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  final int count;
  final int bytes;
  final CleanupMode mode;

  const _SelectionSummary({
    required this.count,
    required this.bytes,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == 0
                  ? 'Tap photos to choose them'
                  : '$count selected · ${formatBytes(bytes)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            mode == CleanupMode.screenshots ? 'Newest first' : 'Largest first',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  final PhotoItem item;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onZoom;

  const _CandidateTile({
    required this.item,
    required this.selected,
    required this.onSelect,
    required this.onZoom,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFFDDE3E8),
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _LocalPhoto(item: item, cacheWidth: 600),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      child: Icon(
                        selected ? Icons.check : Icons.add,
                        color:
                            selected ? Colors.white : const Color(0xFF253238),
                        size: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton.filledTonal(
                      tooltip: 'Inspect photo',
                      onPressed: onZoom,
                      icon: const Icon(Icons.zoom_out_map, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatBytes(item.estimatedBytes),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${(item.resolution / 1000000).toStringAsFixed(1)} MP',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectPhotoScreen extends StatelessWidget {
  final PhotoItem item;

  const _InspectPhotoScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 6,
                child: Center(child: _LocalPhoto(item: item, cacheWidth: 2400)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.width} x ${item.height}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  Text(
                    formatBytes(item.estimatedBytes),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalPhoto extends StatelessWidget {
  final PhotoItem item;
  final int cacheWidth;

  const _LocalPhoto({required this.item, required this.cacheWidth});

  @override
  Widget build(BuildContext context) {
    final path = item.filePath;
    if (path == null) {
      return const ColoredBox(
        color: Color(0xFFE7ECEF),
        child: Icon(Icons.image_outlined),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFFE7ECEF),
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
