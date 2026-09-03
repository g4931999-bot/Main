import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../providers/language_provider.dart';

class PreviewScreen extends StatefulWidget {
  final String title;
  final String videoUrl;
  const PreviewScreen({super.key, required this.title, required this.videoUrl});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  String? _errorKey;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.videoUrl.isEmpty) {
      setState(() => _errorKey = 'video_preview_not_available');
      return;
    }
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initialized = true;
      });
      controller.play();
    } catch (e) {
      if (mounted) setState(() => _errorKey = 'could_not_load_preview');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: _errorKey != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.tr(_errorKey!), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              )
            : _initialized && _controller != null
                ? GestureDetector(
                    onTap: _togglePlayPause,
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio == 0 ? 16 / 9 : _controller!.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_controller!),
                          if (!_controller!.value.isPlaying)
                            Container(
                              color: Colors.black26,
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 64),
                            ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: VideoProgressIndicator(
                              _controller!,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(playedColor: AppColors.purpleLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const CircularProgressIndicator(color: AppColors.purpleLight),
      ),
    );
  }
}