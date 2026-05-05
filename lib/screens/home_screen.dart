import 'package:flutter/material.dart';
import '../models/photo_item.dart';
import '../models/duplicate_group.dart';
import '../services/photo_service.dart';
import '../services/hash_service.dart';
import '../services/quality_service.dart';
import '../services/duplicate_service.dart';
import '../services/mock_data_service.dart';
import 'review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;
  String _status = 'Ready';
  List<DuplicateGroup> _groups = [];

  final _photoService = PhotoService();
  final _hashService = HashService();
  final _qualityService = QualityService();
  final _duplicateService = DuplicateService();
  final _mockDataService = MockDataService();

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _status = 'Requesting photo access...';
      _groups = [];
    });

    try {
      final allowed = await _photoService.requestPermission();

      if (!allowed) {
        setState(() {
          _loading = false;
          _status = 'Photo access denied.';
        });
        return;
      }

      setState(() => _status = 'Loading recent photos...');

      final rawAssets = await _photoService.loadRecentImages(limit: 200);
      final items = <PhotoItem>[];

      int done = 0;

      for (final raw in rawAssets) {
        final hash = await _hashService.computeHash(raw.file);

        final score = _qualityService.score(
          width: raw.asset.width,
          height: raw.asset.height,
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
          ),
        );

        done++;

        if (mounted) {
          setState(() {
            _status = 'Analyzed $done / ${rawAssets.length}';
          });
        }
      }

      final groups = _duplicateService.groupSimilar(items);

      setState(() {
        _loading = false;
        _groups = groups;
        _status = groups.isEmpty
            ? 'No duplicate groups found.'
            : 'Found ${groups.length} duplicate groups';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Scan failed: $e';
      });
    }
  }

  void _loadDemoData() {
    final groups = _mockDataService.getDemoGroups();

    setState(() {
      _groups = groups;
      _status = 'Loaded ${groups.length} demo groups';
    });
  }

  int get _totalPhotosInGroups {
    return _groups.fold(0, (sum, group) => sum + group.items.length);
  }

  int get _suggestedRemovals {
    return _groups.fold(0, (sum, group) => sum + group.suggestedDuplicates.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PhotoCurator AI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _loading ? null : _scan,
                    child: Text(_loading ? 'Scanning...' : 'Scan Photos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading ? null : _loadDemoData,
                    child: const Text('Use Demo Data'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_groups.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatBlock(
                        label: 'Groups',
                        value: _groups.length.toString(),
                      ),
                      _StatBlock(
                        label: 'Photos',
                        value: _totalPhotosInGroups.toString(),
                      ),
                      _StatBlock(
                        label: 'Can Remove',
                        value: _suggestedRemovals.toString(),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_groups.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    final best = group.best;

                    return Card(
                      child: ListTile(
                        title: Text('Group ${index + 1}'),
                        subtitle: Text(
                          '${group.items.length} similar photos • Keep: ${best.title}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewScreen(group: group),
                            ),
                          );
                        },
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

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;

  const _StatBlock({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(label),
      ],
    );
  }
}