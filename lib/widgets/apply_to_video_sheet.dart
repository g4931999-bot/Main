import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/language_provider.dart';
import 'common.dart';

/// Shared "Apply to Video" flow used by the AI Title/Description generator
/// and the SEO Optimizer's "Apply to Video" button. Opens a bottom sheet
/// listing the user's queued videos (GET /videos?status=queued), lets them
/// pick one video AND which platform target on it to update (title/
/// description are stored per-platform — see models/Video.js), then PATCHes
/// PATCH /api/videos/:id/metadata with the chosen text.
///
/// Returns true if the update succeeded (so the caller can show its own
/// success state / pop its own screen if desired), false/null otherwise.
Future<bool?> showApplyToVideoSheet(
  BuildContext context, {
  String? title,
  String? description,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheetContext) => _ApplyToVideoSheet(title: title, description: description),
  );
}

class _ApplyToVideoSheet extends StatefulWidget {
  final String? title;
  final String? description;
  const _ApplyToVideoSheet({this.title, this.description});

  @override
  State<_ApplyToVideoSheet> createState() => _ApplyToVideoSheetState();
}

class _ApplyToVideoSheetState extends State<_ApplyToVideoSheet> {
  bool _loading = true;
  bool _applying = false;
  List<Map<String, dynamic>> _videos = [];
  String? _selectedVideoId;
  String? _selectedPlatform;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Both 'queued' and 'draft' videos can still have their metadata
      // edited server-side (see routes/video.js — anything not yet
      // processing/uploaded/failed) — draft videos are ones still mid-setup.
      final res = await ApiService.instance.listVideos(status: 'queued');
      setState(() => _videos = (res['videos'] as List? ?? []).cast<Map<String, dynamic>>());
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmApply() async {
    if (_selectedVideoId == null || _selectedPlatform == null) return;
    setState(() => _applying = true);
    try {
      await ApiService.instance.updateVideoMetadata(
        _selectedVideoId!,
        platform: _selectedPlatform!,
        title: widget.title,
        description: widget.description,
      );
      if (mounted) {
        showToast(context, context.tr('apply_to_video_success_toast'), isSuccess: true);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedVideo = _videos.firstWhere(
      (v) => v['_id'] == _selectedVideoId,
      orElse: () => <String, dynamic>{},
    );
    final platformTargets = (selectedVideo['platforms'] as List? ?? []).cast<Map<String, dynamic>>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Icon(Icons.send_rounded, color: AppColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(context.tr('apply_to_video_title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
            const SizedBox(height: 4),
            Text(
              context.tr('apply_to_video_subtitle'),
              style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: LoadingView())
            else if (_videos.isEmpty)
              EmptyView(message: context.tr('apply_to_video_empty'), icon: Icons.video_library_outlined)
            else ...[
              ..._videos.map((v) {
                final selected = v['_id'] == _selectedVideoId;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedVideoId = v['_id'];
                    _selectedPlatform = null; // reset platform choice when video changes
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: selected ? AppColors.purple : context.surfaces.border, width: selected ? 1.6 : 1),
                      borderRadius: BorderRadius.circular(12),
                      color: selected ? AppColors.purple.withValues(alpha: 0.08) : null,
                    ),
                    child: Row(children: [
                      Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          size: 18, color: selected ? AppColors.purple : context.surfaces.textDim),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _videoLabel(v),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                      ),
                    ]),
                  ),
                );
              }),
              if (_selectedVideoId != null && platformTargets.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(context.tr('apply_to_video_platform_label'), style: TextStyle(color: context.surfaces.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: platformTargets.map((p) {
                    final platform = p['platform'] as String;
                    final selected = platform == _selectedPlatform;
                    return ChoiceChip(
                      label: Text(platform[0].toUpperCase() + platform.substring(1)),
                      selected: selected,
                      selectedColor: AppColors.purple,
                      labelStyle: TextStyle(color: selected ? Colors.white : null, fontWeight: FontWeight.w700, fontSize: 12.5),
                      onSelected: (_) => setState(() => _selectedPlatform = platform),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedVideoId == null || _selectedPlatform == null || _applying) ? null : _confirmApply,
                  child: _applying
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(context.tr('apply_to_video_confirm_btn')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _videoLabel(Map<String, dynamic> v) {
    final platforms = (v['platforms'] as List? ?? []).cast<Map<String, dynamic>>();
    final firstTitle = platforms.map((p) => p['title']).firstWhere((t) => (t ?? '').toString().isNotEmpty, orElse: () => null);
    return firstTitle ?? context.tr('apply_to_video_untitled');
  }
}
