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
  late PhotoItem _focused;

  @override
  void initState() {
    super.initState();
    _selectedIds =
        widget.group.suggestedDuplicates.map((item) => item.id).toSet();
    _focused = widget.group.best;
  }

  Future<void> _cleanSelected() async {
    if (!widget.canDelete || _selectedIds.isEmpty) return;
    final cleaned = await widget.onDeleteSelected?.call(_selectedIds) ?? false;
    if (mounted && cleaned) {
      Navigator.pop(context);
    }
  }

  void _toggle(PhotoItem item, bool value) {
    if (item.id == widget.group.best.id) return;
    setState(() {
      if (value) {
        _selectedIds.add(item.id);
      } else {
        _selectedIds.remove(item.id);
      }
    });
  }

  void _openZoom(PhotoItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ZoomScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final best = widget.group.best;
    final selectedBytes = widget.group.items
        .where((item) => _selectedIds.contains(item.id))
        .fold(0, (sum, item) => sum + item.estimatedBytes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare duplicates'),
        actions: [
          TextButton.icon(
            onPressed: widget.canDelete && _selectedIds.isNotEmpty
                ? _cleanSelected
                : null,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clean'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _DecisionBar(
              selectedCount: _selectedIds.length,
              selectedBytes: selectedBytes,
              confidence: widget.group.confidence,
            ),
            const SizedBox(height: 12),
            _CompareHero(
              best: best,
              focused: _focused,
              selectedForRemoval: _selectedIds.contains(_focused.id),
              onZoomBest: () => _openZoom(best),
              onZoomFocused: () => _openZoom(_focused),
            ),
            const SizedBox(height: 12),
            _FocusedDetails(
              best: best,
              focused: _focused,
              isKeeper: _focused.id == best.id,
              selectedForRemoval: _selectedIds.contains(_focused.id),
              onToggleRemoval: (value) => _toggle(_focused, value),
            ),
            const SizedBox(height: 16),
            Text('Set', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.group.items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) {
                final item = widget.group.items[index];
                return _PhotoTile(
                  item: item,
                  isFocused: item.id == _focused.id,
                  isKeeper: item.id == best.id,
                  selectedForRemoval: _selectedIds.contains(item.id),
                  onFocus: () => setState(() => _focused = item),
                  onZoom: () => _openZoom(item),
                  onToggleRemoval: (value) => _toggle(item, value),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.canDelete && _selectedIds.isNotEmpty
                  ? _cleanSelected
                  : null,
              icon: const Icon(Icons.delete_outline),
              label: Text(
                widget.canDelete
                    ? 'Delete ${_selectedIds.length} selected'
                    : 'Unlock Pro to batch clean',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionBar extends StatelessWidget {
  final int selectedCount;
  final int selectedBytes;
  final double confidence;

  const _DecisionBar({
    required this.selectedCount,
    required this.selectedBytes,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _MiniMetric(
                label: 'Remove',
                value: '$selectedCount',
              ),
            ),
            Expanded(
              child: _MiniMetric(
                label: 'Reclaim',
                value: formatBytes(selectedBytes),
              ),
            ),
            Expanded(
              child: _MiniMetric(
                label: 'Match',
                value: formatPercent(confidence),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CompareHero extends StatelessWidget {
  final PhotoItem best;
  final PhotoItem focused;
  final bool selectedForRemoval;
  final VoidCallback onZoomBest;
  final VoidCallback onZoomFocused;

  const _CompareHero({
    required this.best,
    required this.focused,
    required this.selectedForRemoval,
    required this.onZoomBest,
    required this.onZoomFocused,
  });

  @override
  Widget build(BuildContext context) {
    final comparingKeeper = focused.id == best.id;

    return Row(
      children: [
        Expanded(
          child: _LargeImagePanel(
            item: best,
            label: 'KEEPER',
            badgeColor: const Color(0xFF15803D),
            onTap: onZoomBest,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LargeImagePanel(
            item: focused,
            label: comparingKeeper
                ? 'KEEPER'
                : selectedForRemoval
                    ? 'REMOVE'
                    : 'REVIEW',
            badgeColor: comparingKeeper
                ? const Color(0xFF15803D)
                : selectedForRemoval
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF475569),
            onTap: onZoomFocused,
          ),
        ),
      ],
    );
  }
}

class _LargeImagePanel extends StatelessWidget {
  final PhotoItem item;
  final String label;
  final Color badgeColor;
  final VoidCallback onTap;

  const _LargeImagePanel({
    required this.item,
    required this.label,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.82,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Positioned.fill(
              child: _PhotoImage(
                item: item,
                fit: BoxFit.cover,
                cacheWidth: 900,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 8,
              bottom: 8,
              child: CircleAvatar(
                radius: 17,
                backgroundColor: Colors.white,
                child: Icon(Icons.zoom_out_map, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusedDetails extends StatelessWidget {
  final PhotoItem best;
  final PhotoItem focused;
  final bool isKeeper;
  final bool selectedForRemoval;
  final ValueChanged<bool> onToggleRemoval;

  const _FocusedDetails({
    required this.best,
    required this.focused,
    required this.isKeeper,
    required this.selectedForRemoval,
    required this.onToggleRemoval,
  });

  @override
  Widget build(BuildContext context) {
    final resolutionDelta = focused.resolution - best.resolution;
    final sizeDelta = focused.estimatedBytes - best.estimatedBytes;
    final scoreDelta = focused.qualityScore - best.qualityScore;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    focused.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: !isKeeper && selectedForRemoval,
                  onChanged: isKeeper ? null : onToggleRemoval,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.aspect_ratio,
                  text: '${focused.width} x ${focused.height}',
                ),
                _InfoChip(
                  icon: Icons.sd_storage_outlined,
                  text: formatBytes(focused.estimatedBytes),
                ),
                _InfoChip(
                  icon: Icons.auto_awesome,
                  text: 'Score ${focused.qualityScore.toStringAsFixed(0)}',
                ),
              ],
            ),
            if (!isKeeper) ...[
              const SizedBox(height: 10),
              _DeltaRow(
                  label: 'Resolution', value: _formatPixels(resolutionDelta)),
              _DeltaRow(
                  label: 'File size', value: _formatSignedBytes(sizeDelta)),
              _DeltaRow(
                label: 'Quality score',
                value: _formatSignedNumber(scoreDelta),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatPixels(int delta) {
    final megapixels = delta / 1000000;
    return '${megapixels >= 0 ? '+' : ''}${megapixels.toStringAsFixed(1)} MP vs keeper';
  }

  String _formatSignedBytes(int delta) {
    return '${delta >= 0 ? '+' : '-'}${formatBytes(delta.abs())} vs keeper';
  }

  String _formatSignedNumber(double delta) {
    return '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)} vs keeper';
  }
}

class _DeltaRow extends StatelessWidget {
  final String label;
  final String value;

  const _DeltaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(text),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final PhotoItem item;
  final bool isFocused;
  final bool isKeeper;
  final bool selectedForRemoval;
  final VoidCallback onFocus;
  final VoidCallback onZoom;
  final ValueChanged<bool> onToggleRemoval;

  const _PhotoTile({
    required this.item,
    required this.isFocused,
    required this.isKeeper,
    required this.selectedForRemoval,
    required this.onFocus,
    required this.onZoom,
    required this.onToggleRemoval,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isFocused
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFE2E8F0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isFocused ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: onFocus,
              onLongPress: onZoom,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _PhotoImage(
                      item: item,
                      fit: BoxFit.cover,
                      cacheWidth: 520,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: isKeeper
                          ? const Color(0xFF15803D)
                          : selectedForRemoval
                              ? const Color(0xFFB91C1C)
                              : const Color(0xFF475569),
                      child: Icon(
                        isKeeper
                            ? Icons.check
                            : selectedForRemoval
                                ? Icons.delete_outline
                                : Icons.visibility_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton.filledTonal(
                      onPressed: onZoom,
                      icon: const Icon(Icons.zoom_out_map, size: 18),
                      tooltip: 'Zoom',
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatBytes(item.estimatedBytes)} • ${item.qualityScore.toStringAsFixed(0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isKeeper ? 'Keeper' : 'Remove',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Switch(
                      value: !isKeeper && selectedForRemoval,
                      onChanged: isKeeper ? null : onToggleRemoval,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomScreen extends StatelessWidget {
  final PhotoItem item;

  const _ZoomScreen({required this.item});

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
                maxScale: 5,
                child: Center(
                  child: _PhotoImage(
                    item: item,
                    fit: BoxFit.contain,
                    cacheWidth: 2200,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white70),
                child: Row(
                  children: [
                    Expanded(child: Text('${item.width} x ${item.height}')),
                    Text(formatBytes(item.estimatedBytes)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoImage extends StatelessWidget {
  final PhotoItem item;
  final BoxFit fit;
  final int? cacheWidth;
  final BorderRadius borderRadius;

  const _PhotoImage({
    required this.item,
    required this.fit,
    required this.cacheWidth,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final path = item.filePath;
    if (path != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(path),
          fit: fit,
          cacheWidth: cacheWidth,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              _FallbackThumb(borderRadius: borderRadius),
        ),
      );
    }

    return _FallbackThumb(borderRadius: borderRadius);
  }
}

class _FallbackThumb extends StatelessWidget {
  final BorderRadius borderRadius;

  const _FallbackThumb({required this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: borderRadius,
      ),
      child: const Center(child: Icon(Icons.image_outlined)),
    );
  }
}
