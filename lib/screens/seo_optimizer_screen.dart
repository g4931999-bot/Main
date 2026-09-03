import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/custom_dropdown.dart';
import '../widgets/apply_to_video_sheet.dart';

/// Screen 2/7 — POST /api/ai/seo-score.
class SeoOptimizerScreen extends StatefulWidget {
  const SeoOptimizerScreen({super.key});
  @override
  State<SeoOptimizerScreen> createState() => _SeoOptimizerScreenState();
}

class _SeoOptimizerScreenState extends State<SeoOptimizerScreen> {
  static const _platforms = {'youtube': 'YouTube', 'instagram': 'Instagram', 'facebook': 'Facebook'};

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  String _platform = 'youtube';
  bool _loading = false;

  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_titleCtrl.text.trim().isEmpty) {
      showToast(context, 'Enter a title first', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final tags = _tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      final res = await ApiService.instance.aiSeoScore(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        tags: tags,
        platform: _platform,
      );
      setState(() => _result = res);
    } catch (e) {
      if (mounted) showAiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _bandColor(int score) {
    if (score > 70) return AppColors.green;
    if (score >= 50) return const Color(0xFFF5A623);
    return AppColors.red;
  }

  String _bandLabel(int score) {
    if (score > 70) return 'Strong';
    if (score >= 50) return 'Needs Work';
    return 'Weak';
  }

  Widget _scoreGauge(int score) {
    final color = _bandColor(score);
    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 160,
              height: 160,
              child: CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 12,
                backgroundColor: context.surfaces.border,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$score', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: color)),
                Text(_bandLabel(score), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownBadge(String label, int value) {
    final color = _bandColor(value);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.4))),
        child: Column(children: [
          Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: context.surfaces.textDim, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final breakdown = _result?['breakdown'] as Map<String, dynamic>?;
    final recommendedTags = (_result?['recommendedTags'] as List? ?? []).cast<String>();

    return Scaffold(
      appBar: AppBar(title: const Text('SEO Optimizer')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Platform', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          CustomDropdown<String>(
            value: _platform,
            items: _platforms.keys.toList(),
            labelBuilder: (v) => _platforms[v] ?? v,
            onChanged: (v) => setState(() => _platform = v ?? _platform),
            prefixIcon: const Icon(Icons.hub_rounded, size: 18, color: AppColors.purple),
          ),
          const SizedBox(height: 16),
          Text('Title', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextFormField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'e.g. I Tried Coding for 24 Hours Straight')),
          const SizedBox(height: 16),
          Text('Description', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextFormField(controller: _descCtrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Video description...')),
          const SizedBox(height: 16),
          Text('Tags (comma separated)', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextFormField(controller: _tagsCtrl, decoration: const InputDecoration(hintText: 'coding, productivity, challenge')),
          const SizedBox(height: 22),
          GradientButton(label: 'Analyze SEO Score', icon: Icons.query_stats_rounded, loading: _loading, onPressed: _analyze),

          if (_result != null) ...[
            const SizedBox(height: 28),
            _scoreGauge((_result!['seoScore'] as num?)?.toInt() ?? 0),
            const SizedBox(height: 20),
            if (breakdown != null)
              Row(children: [
                _breakdownBadge('Title Length', (breakdown['titleScore'] as num?)?.toInt() ?? 0),
                _breakdownBadge('Keyword Density', (breakdown['descScore'] as num?)?.toInt() ?? 0),
                _breakdownBadge('Tag Relevance', (breakdown['tagScore'] as num?)?.toInt() ?? 0),
              ]),
            if ((_result!['notes'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.surfaces.card2, borderRadius: BorderRadius.circular(12)),
                child: Text(_result!['notes'], style: TextStyle(fontSize: 13, color: context.surfaces.textDim)),
              ),
            ],
            if (recommendedTags.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [
                Text('Recommended Tags', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: recommendedTags.join(', ')));
                    showToast(context, 'Tags copied', isSuccess: true);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copy All'),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recommendedTags.map((t) => Chip(label: Text(t), backgroundColor: AppColors.purple.withOpacity(0.12))).toList(),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  final existing = _tagsCtrl.text.trim();
                  final merged = {...existing.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty), ...recommendedTags}.join(', ');
                  setState(() => _tagsCtrl.text = merged);
                  showToast(context, 'Tags appended', isSuccess: true);
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Append to Post'),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showApplyToVideoSheet(
                  context,
                  title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
                  description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Apply to Video'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
