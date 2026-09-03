import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/custom_dropdown.dart';

/// Screen 1/7 of the Creator OS suite — POST /api/ai/ideas.
/// NOTE ("Send to Scheduler"): UploadScreen is file-based (it needs an
/// actual video/image picked before any text field is shown), so there's
/// no existing hook to deep-link a text-only idea straight into it without
/// a larger UploadScreen refactor. Until that refactor happens, "Send to
/// Scheduler" copies the idea's title + script to the clipboard so the
/// creator can paste it in while uploading — a real, working action
/// instead of a dead button.
class AiIdeasScreen extends StatefulWidget {
  const AiIdeasScreen({super.key});
  @override
  State<AiIdeasScreen> createState() => _AiIdeasScreenState();
}

class _AiIdeasScreenState extends State<AiIdeasScreen> {
  static const _niches = ['Tech', 'Gaming', 'Lifestyle', 'Business', 'Fitness', 'Food', 'Travel', 'Comedy'];
  static const _platforms = {'youtube': 'YouTube', 'instagram': 'Instagram', 'facebook': 'Facebook'};

  String _niche = _niches.first;
  String _platform = 'youtube';
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _ideas = [];
  final Set<int> _expanded = {};

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.instance.aiIdeas(niche: _niche, platform: _platform, count: 5);
      final ideas = (res['ideas'] as List? ?? []).cast<Map<String, dynamic>>();
      setState(() {
        _ideas = ideas;
        _expanded.clear();
      });
      if (ideas.isEmpty && mounted) {
        showToast(context, 'No ideas came back — try a different niche', isError: true);
      }
    } catch (e) {
      if (mounted) showAiError(context, e);
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _scoreColor(int score) {
    if (score >= 70) return AppColors.green;
    if (score >= 40) return const Color(0xFFF5A623);
    return AppColors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Ideas')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Niche', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          CustomDropdown<String>(
            value: _niche,
            items: _niches,
            labelBuilder: (v) => v,
            onChanged: (v) => setState(() => _niche = v ?? _niche),
            prefixIcon: const Icon(Icons.category_rounded, size: 18, color: AppColors.purple),
          ),
          const SizedBox(height: 16),
          Text('Platform', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          CustomDropdown<String>(
            value: _platform,
            items: _platforms.keys.toList(),
            labelBuilder: (v) => _platforms[v] ?? v,
            onChanged: (v) => setState(() => _platform = v ?? _platform),
            prefixIcon: const Icon(Icons.hub_rounded, size: 18, color: AppColors.purple),
          ),
          const SizedBox(height: 22),
          GradientButton(label: 'Generate Fresh Ideas', icon: Icons.auto_awesome_rounded, loading: _loading, onPressed: _generate),
          const SizedBox(height: 24),
          if (!_loading && _ideas.isEmpty && _error == null)
            const EmptyView(message: 'Pick a niche and platform, then generate 5 fresh video ideas.', icon: Icons.lightbulb_outline_rounded),
          ..._ideas.asMap().entries.map((entry) {
            final i = entry.key;
            final idea = entry.value;
            final score = (idea['viralScore'] as num?)?.toInt() ?? 0;
            final expanded = _expanded.contains(i);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(idea['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    ),
                    const SizedBox(width: 8),
                    AppBadge(label: _platforms[_platform] ?? _platform, color: AppColors.purple),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.local_fire_department_rounded, size: 16, color: _scoreColor(score)),
                    const SizedBox(width: 5),
                    Text('Viral Score', style: TextStyle(color: context.surfaces.textDim, fontSize: 12)),
                    const Spacer(),
                    Text('$score/100', style: TextStyle(color: _scoreColor(score), fontWeight: FontWeight.w800, fontSize: 13)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      minHeight: 6,
                      backgroundColor: context.surfaces.border,
                      valueColor: AlwaysStoppedAnimation(_scoreColor(score)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('"${idea['hook'] ?? ''}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13.5)),
                  const SizedBox(height: 6),
                  Text(idea['description'] ?? '', style: TextStyle(color: context.surfaces.textDim, fontSize: 13)),
                  if (expanded && (idea['script'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: context.surfaces.card2, borderRadius: BorderRadius.circular(12)),
                      child: Text(idea['script'], style: const TextStyle(fontSize: 13, height: 1.5)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    TextButton.icon(
                      onPressed: () => setState(() => expanded ? _expanded.remove(i) : _expanded.add(i)),
                      icon: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                      label: Text(expanded ? 'Hide Script' : 'Full Script'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        final text = '${idea['title']}\n\n${idea['script'] ?? idea['description']}';
                        Clipboard.setData(ClipboardData(text: text));
                        showToast(context, 'Copied — paste it into your upload', isSuccess: true);
                      },
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Send to Scheduler'),
                    ),
                  ]),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
