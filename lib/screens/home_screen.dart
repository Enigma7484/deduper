import 'package:flutter/material.dart';

import '../models/duplicate_group.dart';
import '../models/photo_item.dart';
import '../models/scan_summary.dart';
import '../services/duplicate_service.dart';
import '../services/hash_service.dart';
import '../services/mock_data_service.dart';
import '../services/photo_service.dart';
import '../services/quality_service.dart';
import '../utils/formatters.dart';
import 'review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;
  bool _isPro = false;
  String _status = 'Run a private on-device scan to find duplicate photos.';
  ScanSummary? _summary;

  final _photoService = PhotoService();
  final _hashService = HashService();
  final _qualityService = QualityService();
  final _duplicateService = DuplicateService();
  final _mockDataService = MockDataService();

  Future<void> _scan({int limit = 600}) async {
    final started = DateTime.now();

    setState(() {
      _loading = true;
      _summary = null;
      _status = 'Requesting photo access...';
    });

    try {
      final allowed = await _photoService.requestPermission();
      if (!allowed) {
        setState(() {
          _loading = false;
          _status = 'Photo access denied. Open Settings to allow library access.';
        });
        return;
      }

      setState(() => _status = 'Loading recent photos...');
      final rawAssets = await _photoService.loadRecentImages(limit: limit);
      final items = <PhotoItem>[];

      for (var index = 0; index < rawAssets.length; index++) {
        final raw = rawAssets[index];
        final fileBytes = await raw.file.length();
        final hash = await _hashService.computeHash(raw.file);
        final score = _qualityService.score(
          width: raw.asset.width,
          height: raw.asset.height,
          fileBytes: fileBytes,
          createdAt: raw.asset.createDateTime,
        );

        items.add(
          PhotoItem(
            id: raw.asset.id,
            title: raw.asset.title ?? 'Untitled',
            width: raw.asset.width,
            height: raw.asset.height,
            createdAt: raw.asset.createDateTime,
            filePath: raw.file.path,
            perceptualHash: hash,
            qualityScore: score,
            estimatedBytes: fileBytes,
          ),
        );

        if (mounted) {
          setState(() {
            _status = 'Analyzed ${index + 1} / ${rawAssets.length} photos';
          });
        }
      }

      final groups = _duplicateService.groupSimilar(items);
      setState(() {
        _loading = false;
        _summary = ScanSummary(
          groups: groups,
          scannedCount: rawAssets.length,
          elapsed: DateTime.now().difference(started),
        );
        _status = groups.isEmpty
            ? 'Library looks clean. No duplicate sets found.'
            : 'Found ${groups.length} cleanup opportunities.';
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _status = 'Scan failed: $error';
      });
    }
  }

  void _loadDemoData() {
    final groups = _mockDataService.getDemoGroups();
    setState(() {
      _summary = ScanSummary(
        groups: groups,
        scannedCount: 14,
        elapsed: const Duration(seconds: 4),
      );
      _status = 'Demo library loaded.';
    });
  }

  void _openPaywall() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PhotoCurator Pro', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Unlimited scans, batch cleanup, smart keeper rules, and exportable cleanup reports. StoreKit or RevenueCat can be connected from this screen.'),
            const SizedBox(height: 16),
            _FeatureRow(icon: Icons.all_inclusive, text: 'Unlimited library scans'),
            _FeatureRow(icon: Icons.auto_awesome, text: 'AI-style keeper recommendations'),
            _FeatureRow(icon: Icons.delete_sweep_outlined, text: 'One-tap batch cleanup review'),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  setState(() => _isPro = true);
                  Navigator.pop(context);
                },
                child: const Text('Unlock demo Pro'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _deleteSelected(DuplicateGroup group, Set<String> selectedIds) async {
    final ids = selectedIds.toList();
    if (ids.isEmpty) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete suggested duplicates?'),
        content: Text('This asks the photo library to delete ${ids.length} selected duplicate photos. Review the system confirmation before approving.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    final deletedIds = await _photoService.deleteAssetsById(ids);
    if (!mounted) return;

    final deletedSet = deletedIds.toSet();
    final currentSummary = _summary;
    if (currentSummary != null && deletedSet.isNotEmpty) {
      final nextGroups = <DuplicateGroup>[];
      for (final currentGroup in currentSummary.groups) {
        if (!identical(currentGroup, group)) {
          nextGroups.add(currentGroup);
          continue;
        }

        final remaining = currentGroup.items
            .where((item) => !deletedSet.contains(item.id))
            .toList();
        if (remaining.length > 1) {
          nextGroups.add(DuplicateGroup(remaining));
        }
      }

      setState(() {
        _summary = ScanSummary(
          groups: nextGroups,
          scannedCount: currentSummary.scannedCount,
          elapsed: currentSummary.elapsed,
        );
        _status = nextGroups.isEmpty
            ? 'Cleanup complete. No duplicate sets remain in the queue.'
            : 'Updated review queue after cleanup.';
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${deletedIds.length} photos.')),
    );
    return deletedIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final groups = summary?.groups ?? <DuplicateGroup>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoCurator AI'),
        actions: [
          TextButton.icon(
            onPressed: _openPaywall,
            icon: Icon(_isPro ? Icons.verified : Icons.workspace_premium_outlined),
            label: Text(_isPro ? 'Pro' : 'Upgrade'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _HeroPanel(
              status: _status,
              loading: _loading,
              isPro: _isPro,
              onScan: () => _scan(limit: _isPro ? 2000 : 250),
              onDemo: _loadDemoData,
              onSettings: () => _photoService.openSettings(),
              onLimitedPicker: () => _photoService.presentLimitedLibraryPicker(),
            ),
            const SizedBox(height: 16),
            _SummaryGrid(summary: summary),
            const SizedBox(height: 16),
            _UpsellBand(isPro: _isPro, onUpgrade: _openPaywall),
            const SizedBox(height: 16),
            Text('Review Queue', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (groups.isEmpty)
              const _EmptyState()
            else
              ...groups.asMap().entries.map(
                    (entry) => _GroupTile(
                      index: entry.key,
                      group: entry.value,
                      onReview: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReviewScreen(
                              group: entry.value,
                              canDelete: _isPro,
                              onDeleteSelected: (selectedIds) => _deleteSelected(
                                entry.value,
                                selectedIds,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final String status;
  final bool loading;
  final bool isPro;
  final VoidCallback onScan;
  final VoidCallback onDemo;
  final VoidCallback onSettings;
  final VoidCallback onLimitedPicker;

  const _HeroPanel({
    required this.status,
    required this.loading,
    required this.isPro,
    required this.onScan,
    required this.onDemo,
    required this.onSettings,
    required this.onLimitedPicker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Private photo cleanup',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
              Chip(label: Text(isPro ? 'PRO' : 'FREE')),
            ],
          ),
          const SizedBox(height: 10),
          Text(status, style: const TextStyle(color: Color(0xFFCBD5E1))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: loading ? null : onScan,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.radar_outlined),
                label: Text(loading ? 'Scanning...' : 'Scan library'),
              ),
              OutlinedButton.icon(
                onPressed: loading ? null : onDemo,
                icon: const Icon(Icons.dataset_outlined),
                label: const Text('Demo'),
              ),
              IconButton.filledTonal(
                onPressed: onLimitedPicker,
                tooltip: 'Manage limited access',
                icon: const Icon(Icons.collections_bookmark_outlined),
              ),
              IconButton.filledTonal(
                onPressed: onSettings,
                tooltip: 'Open settings',
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final ScanSummary? summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final current = summary;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.75,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _MetricCard(label: 'Scanned', value: '${current?.scannedCount ?? 0}'),
        _MetricCard(label: 'Duplicates', value: '${current?.duplicateCount ?? 0}'),
        _MetricCard(label: 'Reclaimable', value: formatBytes(current?.reclaimableBytes ?? 0)),
        _MetricCard(label: 'Confidence', value: formatPercent(current?.averageConfidence ?? 0)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _UpsellBand extends StatelessWidget {
  final bool isPro;
  final VoidCallback onUpgrade;

  const _UpsellBand({required this.isPro, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    if (isPro) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.verified),
          title: Text('Pro tools enabled'),
          subtitle: Text('Batch delete review and larger scans are active in this build.'),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_open_outlined),
        title: const Text('Monetization-ready Pro tier'),
        subtitle: const Text('Free scans are capped. Pro unlocks larger scans and cleanup actions.'),
        trailing: FilledButton(onPressed: onUpgrade, child: const Text('Upgrade')),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final int index;
  final DuplicateGroup group;
  final VoidCallback onReview;

  const _GroupTile({
    required this.index,
    required this.group,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final best = group.best;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text('${group.items.length} similar photos'),
        subtitle: Text('Keep ${best.title} - ${formatBytes(group.reclaimableBytes)} reclaimable'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onReview,
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Text('Scan your library or load the demo to populate the review queue.'),
      ),
    );
  }
}
