import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/duplicate_group.dart';
import '../models/photo_item.dart';
import '../models/scan_summary.dart';
import '../services/duplicate_service.dart';
import '../services/hash_service.dart';
import '../services/mock_data_service.dart';
import '../services/photo_service.dart';
import '../services/quality_service.dart';
import '../services/scan_cache_service.dart';
import '../utils/formatters.dart';
import 'media_cleanup_screen.dart';
import 'review_screen.dart';

enum _ScanSource { recent, album }

class _ScanRequest {
  final CleanupMode mode;
  final _ScanSource source;
  final int limit;
  final String? albumId;
  final String label;

  const _ScanRequest({
    required this.mode,
    required this.source,
    required this.limit,
    required this.label,
    this.albumId,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _devProUnlock = bool.fromEnvironment('DEV_PRO_UNLOCK');

  bool _loading = false;
  bool _cancelRequested = false;
  bool _isPro = _devProUnlock;
  int _processed = 0;
  int _scanTotal = 0;
  String _scanLabel = '';
  ScanSummary? _summary;

  final _photoService = PhotoService();
  final _hashService = HashService();
  final _qualityService = QualityService();
  final _duplicateService = DuplicateService();
  final _mockDataService = MockDataService();
  final _scanCacheService = ScanCacheService();

  @override
  void initState() {
    super.initState();
    _restoreLastScan();
  }

  Future<void> _restoreLastScan() async {
    final cached = await _scanCacheService.load();
    if (mounted && cached != null) setState(() => _summary = cached);
  }

  Future<void> _openScanPicker(CleanupMode initialMode) async {
    final allowed = await _photoService.requestPermission();
    if (!mounted) return;
    if (!allowed) {
      _showMessage('Allow photo access in Settings to start cleaning.');
      return;
    }

    final albums = await _photoService.loadImageAlbums();
    if (!mounted) return;
    final request = await showModalBottomSheet<_ScanRequest>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScanPickerSheet(
        initialMode: initialMode,
        isPro: _isPro,
        albums: albums,
      ),
    );
    if (request != null) await _scan(request);
  }

  Future<void> _scan(_ScanRequest request) async {
    final started = DateTime.now();
    setState(() {
      _loading = true;
      _cancelRequested = false;
      _processed = 0;
      _scanTotal = 0;
      _scanLabel = _modeAction(request.mode);
    });

    try {
      final assets = request.source == _ScanSource.album
          ? await _photoService.loadAlbumImageAssets(
              albumId: request.albumId!,
              limit: request.limit,
            )
          : await _photoService.loadRecentImageAssets(limit: request.limit);
      if (!mounted) return;
      setState(() => _scanTotal = assets.length);

      final items = <PhotoItem>[];
      for (var index = 0; index < assets.length; index++) {
        if (_cancelRequested) break;
        final raw = assets[index];
        try {
          final file = await raw.resolveFile();
          if (file == null || !await file.exists()) {
            throw StateError('Photo is not available on this device.');
          }
          final bytes = await file.length();
          final hash = request.mode == CleanupMode.similar
              ? await _hashService.computeHash(file)
              : '';
          final item = PhotoItem(
            id: raw.id,
            title: raw.title,
            width: raw.width,
            height: raw.height,
            createdAt: raw.createdAt,
            filePath: file.path,
            perceptualHash: hash,
            qualityScore: _qualityService.score(
              width: raw.width,
              height: raw.height,
              fileBytes: bytes,
              createdAt: raw.createdAt,
            ),
            estimatedBytes: bytes,
          );
          if (request.mode != CleanupMode.screenshots || item.isScreenshot) {
            items.add(item);
          }
        } catch (error) {
          debugPrint('Skipping ${raw.id}: $error');
        }
        if (mounted) setState(() => _processed = index + 1);
      }

      if (_cancelRequested) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final groups = request.mode == CleanupMode.similar
          ? _duplicateService.groupSimilar(items)
          : <DuplicateGroup>[];
      final candidates = request.mode == CleanupMode.large
          ? ([...items]..sort(
                  (a, b) => b.estimatedBytes.compareTo(a.estimatedBytes),
                ))
              .take(60)
              .toList()
          : request.mode == CleanupMode.screenshots
              ? items
              : <PhotoItem>[];
      final summary = ScanSummary(
        groups: groups,
        candidates: candidates,
        scannedCount: assets.length,
        elapsed: DateTime.now().difference(started),
        mode: request.mode,
        scopeLabel: request.label,
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _summary = summary;
      });
      if (summary.opportunityCount == 0) {
        await _scanCacheService.clear();
        _showMessage(_emptyResultMessage(request.mode));
      } else {
        await _scanCacheService.save(summary);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('The scan stopped: $error');
    }
  }

  Future<bool> _deleteDuplicateSelection(
    DuplicateGroup group,
    Set<String> selectedIds,
  ) async {
    final deletedIds = await _confirmAndDelete(selectedIds);
    if (!mounted || deletedIds.isEmpty) return false;
    final current = _summary;
    if (current == null) return false;

    final deletedSet = deletedIds.toSet();
    final groups = <DuplicateGroup>[];
    for (final currentGroup in current.groups) {
      if (!identical(currentGroup, group)) {
        groups.add(currentGroup);
        continue;
      }
      final remaining = currentGroup.items
          .where((item) => !deletedSet.contains(item.id))
          .toList();
      if (remaining.length > 1) groups.add(DuplicateGroup(remaining));
    }
    await _replaceSummary(current, groups: groups);
    return true;
  }

  Future<bool> _deleteCandidateSelection(Set<String> selectedIds) async {
    final deletedIds = await _confirmAndDelete(selectedIds);
    if (!mounted || deletedIds.isEmpty) return false;
    final current = _summary;
    if (current == null) return false;
    final deletedSet = deletedIds.toSet();
    final candidates = current.candidates
        .where((item) => !deletedSet.contains(item.id))
        .toList();
    await _replaceSummary(current, candidates: candidates);
    return true;
  }

  Future<List<String>> _confirmAndDelete(Set<String> selectedIds) async {
    if (selectedIds.isEmpty) return [];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text('Remove ${selectedIds.length} photos?'),
        content: const Text(
          'Apple will show one final confirmation. Deleted photos remain in Recently Deleted before permanent removal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep them'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return [];
    final deleted = await _photoService.deleteAssetsById(selectedIds.toList());
    if (mounted) _showMessage('Removed ${deleted.length} photos.');
    return deleted;
  }

  Future<void> _replaceSummary(
    ScanSummary current, {
    List<DuplicateGroup>? groups,
    List<PhotoItem>? candidates,
  }) async {
    final next = ScanSummary(
      groups: groups ?? current.groups,
      candidates: candidates ?? current.candidates,
      scannedCount: current.scannedCount,
      elapsed: current.elapsed,
      mode: current.mode,
      scopeLabel: current.scopeLabel,
    );
    setState(() => _summary = next);
    if (next.opportunityCount == 0) {
      await _scanCacheService.clear();
    } else {
      await _scanCacheService.save(next);
    }
  }

  void _openCandidateReview() {
    final summary = _summary;
    if (summary == null || summary.candidates.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaCleanupScreen(
          mode: summary.mode,
          items: summary.candidates,
          canDelete: _isPro,
          onDeleteSelected: _deleteCandidateSelection,
        ),
      ),
    );
  }

  void _loadDemoData() {
    final summary = ScanSummary(
      groups: _mockDataService.getDemoGroups(),
      scannedCount: 14,
      elapsed: const Duration(seconds: 4),
      scopeLabel: 'Demo library',
    );
    setState(() => _summary = summary);
    _scanCacheService.save(summary);
  }

  void _openPaywall() {
    final canDemoUnlock = kDebugMode || _devProUnlock;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.workspace_premium_outlined, size: 32),
              const SizedBox(height: 12),
              Text('Curate Pro',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Clean larger batches, remove selected photos, and use every focused cleanup tool.',
              ),
              const SizedBox(height: 18),
              const _FeatureRow(Icons.all_inclusive, 'Larger cleanup sessions'),
              const _FeatureRow(Icons.compare_outlined, 'Detailed comparisons'),
              const _FeatureRow(Icons.delete_sweep_outlined, 'Batch removal'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canDemoUnlock
                      ? () {
                          setState(() => _isPro = true);
                          Navigator.pop(context);
                        }
                      : null,
                  child: Text(canDemoUnlock
                      ? 'Enable developer Pro'
                      : 'Purchases coming soon'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandMark(),
            SizedBox(width: 9),
            Text('Curate'),
          ],
        ),
        actions: [
          if (_isPro)
            const Padding(
              padding: EdgeInsets.only(right: 2),
              child: Chip(
                avatar: Icon(Icons.check_circle, size: 16),
                label: Text('Pro'),
                visualDensity: VisualDensity.compact,
              ),
            )
          else
            TextButton(onPressed: _openPaywall, child: const Text('Go Pro')),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') _photoService.openSettings();
              if (value == 'access') {
                _photoService.presentLimitedLibraryPicker();
              }
              if (value == 'demo') _loadDemoData();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'access',
                child: ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('Photo access'),
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),
              if (_devProUnlock || kDebugMode)
                const PopupMenuItem(
                  value: 'demo',
                  child: ListTile(
                    leading: Icon(Icons.science_outlined),
                    title: Text('Load demo'),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
          children: [
            Text(
              'Make room for what matters.',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF172126),
                  ),
            ),
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: Color(0xFF39735B)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Private by design. Every photo stays on this iPhone.',
                    style: TextStyle(color: Color(0xFF526168)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (_loading)
              _ScanProgressPanel(
                label: _scanLabel,
                processed: _processed,
                total: _scanTotal,
                onCancel: () => setState(() => _cancelRequested = true),
              )
            else if (summary != null && summary.opportunityCount > 0)
              _ResumePanel(
                summary: summary,
                onOpen: summary.mode == CleanupMode.similar
                    ? () => _openDuplicateGroup(summary.groups.first)
                    : _openCandidateReview,
              )
            else
              const _FreshStartPanel(),
            const SizedBox(height: 24),
            _SectionTitle(
              title: 'Choose a cleanup',
              trailing: _isPro ? 'All tools unlocked' : 'Free scan available',
            ),
            const SizedBox(height: 10),
            _CleanupTool(
              icon: Icons.filter_none,
              color: const Color(0xFF39735B),
              tint: const Color(0xFFE3F1EA),
              title: 'Similar photos',
              subtitle: 'Compare near-duplicates and keep the strongest shot',
              onTap: () => _openScanPicker(CleanupMode.similar),
            ),
            const SizedBox(height: 9),
            _CleanupTool(
              icon: Icons.screenshot_outlined,
              color: const Color(0xFF9A5B24),
              tint: const Color(0xFFFFEBD7),
              title: 'Screenshots',
              subtitle: 'Collect forgotten captures for a quick visual sweep',
              onTap: () => _openScanPicker(CleanupMode.screenshots),
            ),
            const SizedBox(height: 9),
            _CleanupTool(
              icon: Icons.photo_size_select_large_outlined,
              color: const Color(0xFF315E80),
              tint: const Color(0xFFDDECF5),
              title: 'Large photos',
              subtitle: 'Start with the files using the most storage',
              onTap: () => _openScanPicker(CleanupMode.large),
            ),
            if (summary?.mode == CleanupMode.similar &&
                summary!.groups.isNotEmpty) ...[
              const SizedBox(height: 26),
              _SectionTitle(
                title: 'Review queue',
                trailing: '${summary.groups.length} sets',
              ),
              const SizedBox(height: 10),
              ...summary.groups.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _GroupTile(
                        index: entry.key,
                        group: entry.value,
                        onTap: () => _openDuplicateGroup(entry.value),
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 20),
            const _SafetyNote(),
          ],
        ),
      ),
    );
  }

  void _openDuplicateGroup(DuplicateGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          group: group,
          canDelete: _isPro,
          onDeleteSelected: (ids) => _deleteDuplicateSelection(group, ids),
        ),
      ),
    );
  }
}

class _ScanPickerSheet extends StatefulWidget {
  final CleanupMode initialMode;
  final bool isPro;
  final List<PhotoAlbumOption> albums;

  const _ScanPickerSheet({
    required this.initialMode,
    required this.isPro,
    required this.albums,
  });

  @override
  State<_ScanPickerSheet> createState() => _ScanPickerSheetState();
}

class _ScanPickerSheetState extends State<_ScanPickerSheet> {
  late CleanupMode _mode = widget.initialMode;

  @override
  Widget build(BuildContext context) {
    final recentOptions = widget.isPro ? const [100, 250, 500] : const [100];
    final albumLimit = widget.isPro ? 500 : 100;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text('Set your cleanup scope',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            const Text('Choose what to find, then choose where to look.'),
            const SizedBox(height: 18),
            SegmentedButton<CleanupMode>(
              segments: const [
                ButtonSegment(
                  value: CleanupMode.similar,
                  icon: Icon(Icons.filter_none),
                  label: Text('Similar'),
                ),
                ButtonSegment(
                  value: CleanupMode.screenshots,
                  icon: Icon(Icons.screenshot_outlined),
                  label: Text('Shots'),
                ),
                ButtonSegment(
                  value: CleanupMode.large,
                  icon: Icon(Icons.photo_size_select_large_outlined),
                  label: Text('Large'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
            const SizedBox(height: 24),
            Text('Recent photos',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final limit in recentOptions)
                  ActionChip(
                    avatar: const Icon(Icons.schedule, size: 17),
                    label: Text('Latest $limit'),
                    onPressed: () => Navigator.pop(
                      context,
                      _ScanRequest(
                        mode: _mode,
                        source: _ScanSource.recent,
                        limit: limit,
                        label: 'Latest $limit',
                      ),
                    ),
                  ),
              ],
            ),
            if (!widget.isPro) ...[
              const SizedBox(height: 8),
              const Text(
                'Pro unlocks 250 and 500-photo sessions.',
                style: TextStyle(color: Color(0xFF69787F)),
              ),
            ],
            const SizedBox(height: 24),
            Text('Albums', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (widget.albums.isEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.photo_album_outlined),
                title: Text('No albums available'),
              )
            else
              ...widget.albums.take(18).map(
                    (album) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.photo_album_outlined),
                      ),
                      title: Text(album.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${album.assetCount} photos'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(
                        context,
                        _ScanRequest(
                          mode: _mode,
                          source: _ScanSource.album,
                          albumId: album.id,
                          limit: album.assetCount.clamp(1, albumLimit),
                          label: album.name,
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF39735B),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
    );
  }
}

class _FreshStartPanel extends StatelessWidget {
  const _FreshStartPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF172126),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF2C393E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.collections_outlined,
                color: Color(0xFF9FCEB8), size: 29),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A lighter library starts here',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Pick one focused cleanup below. Nothing is removed without your approval.',
                  style: TextStyle(color: Color(0xFFC9D3D6), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumePanel extends StatelessWidget {
  final ScanSummary summary;
  final VoidCallback onOpen;

  const _ResumePanel({required this.summary, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final items = summary.mode == CleanupMode.similar
        ? summary.groups.expand((group) => group.items).take(3).toList()
        : summary.candidates.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF172126),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 116,
            child: Row(
              children: [
                for (final item in items)
                  Expanded(child: _HomeThumb(item: item)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _modeResultTitle(
                            summary.mode, summary.opportunityCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${summary.scopeLabel} · up to ${formatBytes(summary.reclaimableBytes)}',
                        style: const TextStyle(color: Color(0xFFC9D3D6)),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9FCEB8),
                    foregroundColor: const Color(0xFF172126),
                  ),
                  child: const Text('Review'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanProgressPanel extends StatelessWidget {
  final String label;
  final int processed;
  final int total;
  final VoidCallback onCancel;

  const _ScanProgressPanel({
    required this.label,
    required this.processed,
    required this.total,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? null : processed / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF172126),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF9FCEB8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(value: progress, minHeight: 7),
          const SizedBox(height: 10),
          Text(
            total == 0 ? 'Preparing photos…' : '$processed of $total analyzed',
            style: const TextStyle(color: Color(0xFFC9D3D6)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionTitle({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CleanupTool extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CleanupTool({
    required this.icon,
    required this.color,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFDDE3E8)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF647178), height: 1.25)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final int index;
  final DuplicateGroup group;
  final VoidCallback onTap;

  const _GroupTile({
    required this.index,
    required this.group,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFDDE3E8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 82,
          child: Row(
            children: [
              SizedBox(
                width: 82,
                child: _HomeThumb(item: group.best),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set ${index + 1} · ${group.items.length} photos',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('${formatBytes(group.reclaimableBytes)} recoverable'),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeThumb extends StatelessWidget {
  final PhotoItem item;

  const _HomeThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    final path = item.filePath;
    if (path == null) {
      return const ColoredBox(
        color: Color(0xFF2C393E),
        child: Icon(Icons.image_outlined, color: Color(0xFF9FCEB8)),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: 520,
      errorBuilder: (_, __, ___) => const ColoredBox(
        color: Color(0xFF2C393E),
        child: Icon(Icons.image_outlined, color: Color(0xFF9FCEB8)),
      ),
    );
  }
}

class _SafetyNote extends StatelessWidget {
  const _SafetyNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, size: 20, color: Color(0xFF39735B)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'You approve every removal. Apple also keeps deleted photos recoverable in Recently Deleted.',
            style: TextStyle(color: Color(0xFF647178), height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 9),
          Text(text),
        ],
      ),
    );
  }
}

String _modeAction(CleanupMode mode) => switch (mode) {
      CleanupMode.similar => 'Finding similar photos',
      CleanupMode.screenshots => 'Gathering screenshots',
      CleanupMode.large => 'Measuring large photos',
    };

String _emptyResultMessage(CleanupMode mode) => switch (mode) {
      CleanupMode.similar => 'No similar photo sets found in this scope.',
      CleanupMode.screenshots => 'No screenshots found in this scope.',
      CleanupMode.large => 'No available photos found in this scope.',
    };

String _modeResultTitle(CleanupMode mode, int count) => switch (mode) {
      CleanupMode.similar => '$count similar sets ready',
      CleanupMode.screenshots => '$count screenshots gathered',
      CleanupMode.large => '$count large photos ranked',
    };
