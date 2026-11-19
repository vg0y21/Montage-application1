import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/edit_project.dart';
import '../services/ffmpeg_engine.dart';
import '../widgets/kinetic_jog_wheel.dart';
import '../widgets/kinetic_trim_bar.dart';

class EditorScreen extends StatefulWidget {
  final String videoPath;

  const EditorScreen({super.key, required this.videoPath});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late VideoPlayerController _controller;
  late EditProject _project;
  StudioLens _activeLens = StudioLens.trim;

  bool _initialized = false;
  bool _isExporting = false;
  double _exportProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _project = EditProject(videoPath: widget.videoPath);
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller.initialize();
    _project.videoDuration = _controller.value.duration;
    _project.trimEnd = _controller.value.duration;
    _controller.addListener(_onTick);
    await _controller.setLooping(true);
    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  void _onTick() {
    if (!mounted || !_initialized) return;
    final pos = _controller.value.position;
    if (_controller.value.isPlaying && pos >= _project.trimEnd) {
      _controller.seekTo(_project.trimStart);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized) return;
    HapticFeedback.lightImpact();
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      if (_controller.value.position < _project.trimStart ||
          _controller.value.position >= _project.trimEnd) {
        _controller.seekTo(_project.trimStart);
      }
      _controller.play();
    }
    setState(() {});
  }

  Future<void> _pickMusic() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null && res.files.single.path != null) {
      setState(() {
        _project.musicPath = res.files.single.path;
        _project.musicName = res.files.single.name;
      });
    }
  }

  Future<void> _startExport() async {
    if (_isExporting) return;
    await _controller.pause();
    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    final result = await FfmpegEngine.exportProject(
      project: _project,
      onProgress: (p) {
        if (mounted) setState(() => _exportProgress = p);
      },
    );

    if (!mounted) return;
    setState(() => _isExporting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            result.success ? const Color(0xFF0D2B2F) : const Color(0xFF3A121C),
        content: Text(
          result.message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTopHud(),
                Expanded(child: _buildVideoStage()),
                if (_initialized) ...[
                  const SizedBox(height: 10),
                  KineticJogWheel(
                    position: _controller.value.position,
                    duration: _project.videoDuration,
                    onScrub: (d) => _controller.seekTo(d),
                  ),
                  const SizedBox(height: 10),
                  _buildActiveToolDeck(),
                  const SizedBox(height: 10),
                  _buildOrbitalLensDock(),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          if (_isExporting) _buildExportOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopHud() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _iconPill(
            Icons.arrow_back_ios_new_rounded,
            () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          _iconPill(
            Icons.refresh_rounded,
            () {
              HapticFeedback.mediumImpact();
              setState(() {
                _project.resetAll();
                _controller.setPlaybackSpeed(1.0);
                _controller.setVolume(1.0);
              });
            },
          ),
          const Spacer(),
          GestureDetector(
            onTap: _initialized ? _startExport : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF0077FF)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withAlpha(75),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF080A0F)),
                  SizedBox(width: 5),
                  Text(
                    'تصدير',
                    style: TextStyle(
                      color: Color(0xFF080A0F),
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconPill(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF121622),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(22)),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _buildVideoStage() {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      );
    }

    final nativeRatio = _controller.value.aspectRatio;
    final displayRatio = _project.aspectRatioMode.ratio ?? nativeRatio;

    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF04060A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(24)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: displayRatio,
                child: ClipRect(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      _project.buildPreviewColorMatrix(),
                    ),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(_project.flipHorizontal ? -1.0 : 1.0, 1.0)
                        ..rotateZ(_project.rotationQuarterTurns * math.pi / 2),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFF080A0F).withAlpha(180),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withAlpha(190),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 36,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveToolDeck() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: switch (_activeLens) {
          StudioLens.trim => KineticTrimBar(
              key: const ValueKey('trim'),
              duration: _project.videoDuration,
              start: _project.trimStart,
              end: _project.trimEnd,
              position: _controller.value.position,
              onChanged: (s, e) {
                setState(() {
                  _project.trimStart = s;
                  _project.trimEnd = e;
                });
                _controller.seekTo(s);
              },
            ),
          StudioLens.speed => _buildSpeedDeck(),
          StudioLens.color => _buildColorDeck(),
          StudioLens.audio => _buildAudioDeck(),
          StudioLens.frame => _buildFrameDeck(),
        },
      ),
    );
  }

  Widget _buildSpeedDeck() {
    const speeds = [0.5, 0.75, 1.0, 1.5, 2.0, 3.0];
    return _deckBox(
      key: const ValueKey('speed'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سرعة الحركة (${_project.speed.toStringAsFixed(2)}x)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: speeds.map((s) {
              final active = (_project.speed - s).abs() < 0.01;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _project.speed = s);
                  _controller.setPlaybackSpeed(s);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF00E5FF)
                        : Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${s}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: active ? const Color(0xFF080A0F) : Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorDeck() {
    return _deckBox(
      key: const ValueKey('color'),
      child: Column(
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: FilterPreset.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = FilterPreset.values[i];
                final active = _project.filterPreset == p;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _project.applyPreset(p));
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFFF4D6D)
                          : Colors.white.withAlpha(14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          _miniSlider(
            'السطوع',
            _project.brightness,
            -0.35,
            0.35,
            (v) => setState(() => _project.brightness = v),
          ),
          _miniSlider(
            'التباين',
            _project.contrast,
            0.6,
            1.6,
            (v) => setState(() => _project.contrast = v),
          ),
          _miniSlider(
            'التشبع',
            _project.saturation,
            0.0,
            1.9,
            (v) => setState(() => _project.saturation = v),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioDeck() {
    return _deckBox(
      key: const ValueKey('audio'),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickMusic,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withAlpha(25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withAlpha(120),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.music_note_rounded,
                            size: 18, color: Color(0xFF00E5FF)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _project.musicName ?? 'إضافة موسيقى من جهازك',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _project.muteOriginal = !_project.muteOriginal;
                    _controller.setVolume(
                        _project.muteOriginal ? 0.0 : _project.originalVolume);
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _project.muteOriginal
                        ? const Color(0xFFFF4D6D)
                        : Colors.white.withAlpha(16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _project.muteOriginal
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          if (!_project.muteOriginal)
            _miniSlider(
              'صوت الفيديو',
              _project.originalVolume,
              0.0,
              1.0,
              (v) {
                setState(() => _project.originalVolume = v);
                _controller.setVolume(v);
              },
            ),
          if (_project.musicPath != null)
            _miniSlider(
              'صوت الموسيقى',
              _project.musicVolume,
              0.0,
              1.0,
              (v) => setState(() => _project.musicVolume = v),
            ),
        ],
      ),
    );
  }

  Widget _buildFrameDeck() {
    return _deckBox(
      key: const ValueKey('frame'),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: AspectRatioMode.values.map((m) {
              final active = _project.aspectRatioMode == m;
              return GestureDetector(
                onTap: () => setState(() => _project.aspectRatioMode = m),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF00E5FF)
                        : Colors.white.withAlpha(14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? const Color(0xFF080A0F) : Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _actionChip(
                  Icons.rotate_right_rounded,
                  'تدوير 90°',
                  () => setState(() => _project.rotationQuarterTurns =
                      (_project.rotationQuarterTurns + 1) % 4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionChip(
                  Icons.flip_rounded,
                  'قلب أفقي',
                  () => setState(
                      () => _project.flipHorizontal = !_project.flipHorizontal),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionChip(
                  Icons.hd_rounded,
                  '${_project.exportHeight}p',
                  () => setState(() => _project.exportHeight =
                      _project.exportHeight == 1080 ? 720 : 1080),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF00E5FF)),
            const SizedBox(width: 5),
            Text(label,
                style:
                    const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _miniSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.white.withAlpha(185)),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _deckBox({Key? key, required Widget child}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121622),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: child,
    );
  }

  Widget _buildOrbitalLensDock() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF10141F),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: StudioLens.values.map((lens) {
          final active = _activeLens == lens;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeLens = lens);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF00E5FF).withAlpha(32)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF00E5FF).withAlpha(150)
                        : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      lens.icon,
                      size: 19,
                      color: active
                          ? const Color(0xFF00E5FF)
                          : Colors.white.withAlpha(140),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lens.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active
                            ? const Color(0xFF00E5FF)
                            : Colors.white.withAlpha(140),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExportOverlay() {
    final pct = (_exportProgress * 100).round();
    return Container(
      color: const Color(0xFF080A0F).withAlpha(235),
      child: Center(
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF121622),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF00E5FF).withAlpha(110)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 86,
                height: 86,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _exportProgress > 0 ? _exportProgress : null,
                      strokeWidth: 6,
                      color: const Color(0xFF00E5FF),
                      backgroundColor: Colors.white.withAlpha(24),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'جاري تصدير الفيديو...',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'محرك PULSE يعالج الألوان والسرعة بدقة ${_project.exportHeight}p',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(155),
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => FfmpegEngine.cancelAll(),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Color(0xFFFF4D6D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
