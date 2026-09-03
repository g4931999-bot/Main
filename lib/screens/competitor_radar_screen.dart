import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Screen 3/7 — GET/POST/DELETE /api/analytics/competitors.
///
/// NOTE on the "Alert Banner ... highlights trending videos gaining >2x
/// views": the backend's VPH (Views Per Hour) is the closest real signal
/// available — it's an AVERAGE across each competitor's recent uploads, not
/// a per-video delta against that video's own historical baseline, so a
/// true "2x their normal rate" comparison isn't something the API returns
/// yet. This screen instead flags any tracked competitor whose current VPH
/// is more than 2x the group's average VPH — an honest, computable
/// approximation of "this one is currently trending relative to the
/// others you're tracking" — rather than a number the backend can't back up.
class CompetitorRadarScreen extends StatefulWidget {
  const CompetitorRadarScreen({super.key});
  @override
  State<CompetitorRadarScreen> createState() => _CompetitorRadarScreenState();
}

class _CompetitorRadarScreenState extends State<CompetitorRadarScreen> {
  final _inputCtrl = TextEditingController();
  bool _loading = true;
  bool _adding = false;
  List<Map<String, dynamic>> _competitors = [];
  String? _apiKeyError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.instance.listCompetitors();
      final list = (res['competitors'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _competitors = list;
        _apiKeyError = list.isNotEmpty && list.every((c) => (c['lastStats']?['error'] ?? '').toString().contains('YOUTUBE_DATA_API_KEY'))
            ? list.first['lastStats']['error']
            : null;
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCompetitor() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() => _adding = true);
    try {
      final isHandle = input.startsWith('@');
      await ApiService.instance.addCompetitor(
        channelId: isHandle ? null : input,
        handle: isHandle ? input : null,
      );
      _inputCtrl.clear();
      await _load();
      if (mounted) showToast(context, 'Competitor added', isSuccess: true);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _remove(String id) async {
    try {
      await ApiService.instance.deleteCompetitor(id);
      setState(() => _competitors.removeWhere((c) => c['_id'] == id));
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  String _fmt(num? n) {
    if (n == null) return '—';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final vphValues = _competitors
        .map((c) => (c['lastStats']?['vph'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final avgVph = vphValues.isEmpty ? 0.0 : vphValues.reduce((a, b) => a + b) / vphValues.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Competitor Radar')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.purple,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _inputCtrl,
                  decoration: const InputDecoration(hintText: '@handle or channel ID'),
                  onFieldSubmitted: (_) => _addCompetitor(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _adding ? null : _addCompetitor,
                  child: _adding
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_rounded),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            if (_apiKeyError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.red.withOpacity(0.08), border: Border.all(color: AppColors.red.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Competitor stats unavailable — YouTube Data API key not configured on the server.', style: TextStyle(color: AppColors.red, fontSize: 12.5))),
                ]),
              ),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingView())
            else if (_competitors.isEmpty)
              const EmptyView(message: 'Track a competitor channel to see their subscriber count and Views Per Hour.', icon: Icons.radar_rounded)
            else
              ..._competitors.map((c) {
                final stats = c['lastStats'] as Map<String, dynamic>? ?? {};
                final vph = (stats['vph'] as num?)?.toDouble();
                final isTrending = vph != null && avgVph > 0 && vph > avgVph * 2;
                final thumbnail = (stats['thumbnail'] ?? '').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: isTrending ? AppColors.green.withOpacity(0.5) : context.surfaces.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.purple.withOpacity(0.14),
                          backgroundImage: thumbnail.isNotEmpty ? NetworkImage(thumbnail) : null,
                          child: thumbnail.isEmpty ? const Icon(Icons.person_rounded, color: AppColors.purple) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['label'] ?? c['handle'] ?? c['channelId'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text('${_fmt(stats['subscriberCount'] as num?)} subscribers', style: TextStyle(color: context.surfaces.textDim, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => _remove(c['_id']), icon: const Icon(Icons.close_rounded, size: 18)),
                      ]),
                      if (stats['error'] != null && !stats['error'].toString().contains('YOUTUBE_DATA_API_KEY')) ...[
                        const SizedBox(height: 8),
                        Text(stats['error'], style: const TextStyle(color: AppColors.red, fontSize: 11.5)),
                      ] else if (vph != null) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          Icon(Icons.speed_rounded, size: 15, color: isTrending ? AppColors.green : context.surfaces.textDim),
                          const SizedBox(width: 5),
                          Text('${vph.toStringAsFixed(1)} VPH', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: isTrending ? AppColors.green : null)),
                          if (isTrending) ...[
                            const SizedBox(width: 8),
                            const AppBadge(label: '🔥 Trending 2x+', color: AppColors.green),
                          ],
                        ]),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
