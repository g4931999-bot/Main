import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Screen 5/7 — thumbnail mockup previewer + on-device contrast analysis.
///
/// The "Visual Score" is computed for real, on-device, from the picked
/// image's actual pixels (luminance standard deviation = contrast proxy,
/// mean luminance = brightness) — not a placeholder/random number. There's
/// no ML-based composition/face-detection scoring here (that would need a
/// vision model this app doesn't have access to); this is a genuine but
/// simple contrast+brightness heuristic, labelled as such.
class VisualAnalyzerScreen extends StatefulWidget {
  const VisualAnalyzerScreen({super.key});
  @override
  State<VisualAnalyzerScreen> createState() => _VisualAnalyzerScreenState();
}

enum _MockupTab { instagram, youtube, facebook }

class _VisualAnalyzerScreenState extends State<VisualAnalyzerScreen> {
  File? _image;
  final _titleCtrl = TextEditingController(text: 'Your Video Title Here');
  _MockupTab _tab = _MockupTab.instagram;
  bool _analyzing = false;
  double? _contrastScore; // 0-100
  double? _brightness; // 0-255

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _contrastScore = null;
      _brightness = null;
    });
    await _analyze();
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() => _analyzing = true);
    try {
      final bytes = await _image!.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120); // downscale for a fast, cheap sample
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return;

      final pixels = byteData.buffer.asUint8List();
      final luminances = <double>[];
      for (int i = 0; i < pixels.length; i += 4) {
        final r = pixels[i], g = pixels[i + 1], b = pixels[i + 2];
        luminances.add(0.299 * r + 0.587 * g + 0.114 * b);
      }
      final mean = luminances.reduce((a, b) => a + b) / luminances.length;
      final variance = luminances.map((l) => (l - mean) * (l - mean)).reduce((a, b) => a + b) / luminances.length;
      final stdDev = math.sqrt(variance.abs());
      final normalizedContrast = (stdDev / 128 * 100).clamp(0, 100).toDouble();

      setState(() {
        _brightness = mean;
        _contrastScore = normalizedContrast;
      });
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Color _scoreColor(double score) {
    if (score >= 60) return AppColors.green;
    if (score >= 35) return const Color(0xFFF5A623);
    return AppColors.red;
  }

  String _readabilityNote() {
    if (_contrastScore == null || _brightness == null) return '';
    if (_contrastScore! < 35) return 'Low contrast — text overlays may be hard to read. Try a bolder background or add a dark gradient overlay.';
    if (_brightness! < 60) return 'Image is quite dark overall — white text should stay readable, but check on a small mobile thumbnail.';
    if (_brightness! > 200) return 'Image is quite bright overall — use dark text or add a subtle overlay for contrast.';
    return 'Good balance of contrast and brightness for thumbnail text.';
  }

  Widget _mockupFrame() {
    final title = _titleCtrl.text.trim().isEmpty ? 'Your Video Title Here' : _titleCtrl.text.trim();
    switch (_tab) {
      case _MockupTab.instagram:
        return _phoneFrame(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                const CircleAvatar(radius: 14, backgroundColor: AppColors.purple),
                const SizedBox(width: 8),
                const Text('your_channel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
            AspectRatio(aspectRatio: 1, child: _imageBox()),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
            ),
          ]),
        );
      case _MockupTab.youtube:
        return _phoneFrame(
          child: Column(children: [
            AspectRatio(aspectRatio: 16 / 9, child: _imageBox()),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const CircleAvatar(radius: 16, backgroundColor: AppColors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text('Your Channel · 12K views', style: TextStyle(color: context.surfaces.textDim, fontSize: 11)),
                  ]),
                ),
              ]),
            ),
          ]),
        );
      case _MockupTab.facebook:
        return _phoneFrame(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                const CircleAvatar(radius: 14, backgroundColor: AppColors.purple),
                const SizedBox(width: 8),
                const Text('Your Page', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 12.5)))),
            const SizedBox(height: 8),
            AspectRatio(aspectRatio: 1.3, child: _imageBox()),
          ]),
        );
    }
  }

  Widget _phoneFrame({required Widget child}) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _imageBox() {
    if (_image == null) {
      return Container(color: context.surfaces.card2, child: const Center(child: Icon(Icons.image_outlined, size: 40)));
    }
    return Image.file(_image!, fit: BoxFit.cover, width: double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Visual Analyzer')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 140,
              decoration: BoxDecoration(border: Border.all(color: AppColors.purple, style: BorderStyle.solid), borderRadius: BorderRadius.circular(16)),
              child: _image == null
                  ? const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_photo_alternate_rounded, color: AppColors.purple, size: 30),
                        SizedBox(height: 8),
                        Text('Tap to pick a thumbnail', style: TextStyle(fontWeight: FontWeight.w600)),
                      ]),
                    )
                  : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_image!, fit: BoxFit.cover, width: double.infinity)),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(controller: _titleCtrl, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'Preview title text')),
          const SizedBox(height: 20),
          SegmentedButton<_MockupTab>(
            segments: const [
              ButtonSegment(value: _MockupTab.instagram, label: Text('Instagram Feed')),
              ButtonSegment(value: _MockupTab.youtube, label: Text('YouTube Mobile')),
              ButtonSegment(value: _MockupTab.facebook, label: Text('Facebook Post')),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
          const SizedBox(height: 16),
          _mockupFrame(),
          if (_image != null) ...[
            const SizedBox(height: 24),
            Text('Visual Score', style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (_analyzing)
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: LoadingView())
            else if (_contrastScore != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: context.surfaces.border), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.contrast_rounded, color: _scoreColor(_contrastScore!), size: 20),
                      const SizedBox(width: 8),
                      Text('Contrast: ${_contrastScore!.toStringAsFixed(0)}/100', style: TextStyle(fontWeight: FontWeight.w800, color: _scoreColor(_contrastScore!))),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(value: _contrastScore! / 100, minHeight: 6, backgroundColor: context.surfaces.border, valueColor: AlwaysStoppedAnimation(_scoreColor(_contrastScore!))),
                    ),
                    const SizedBox(height: 12),
                    Text(_readabilityNote(), style: TextStyle(color: context.surfaces.textDim, fontSize: 12.5)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
