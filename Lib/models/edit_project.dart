import 'package:flutter/material.dart';

enum FilterPreset {
  original('أصلي', 0.0, 1.0, 1.0, null),
  cinematic('سينمائي', -0.03, 1.18, 1.15, 'rs=0.06:gs=0.01:bs=-0.07'),
  neonNight('نيون ليلي', -0.05, 1.25, 1.35, 'rs=-0.04:gs=0.03:bs=0.10'),
  noir('نوار حاد', -0.02, 1.35, 0.0, null),
  vivid('تباين فائق', 0.03, 1.22, 1.45, null),
  golden('غروب ذهبي', 0.04, 1.10, 1.25, 'rs=0.10:gs=0.04:bs=-0.09');

  final String label;
  final double defaultBrightness;
  final double defaultContrast;
  final double defaultSaturation;
  final String? colorBalance;

  const FilterPreset(
    this.label,
    this.defaultBrightness,
    this.defaultContrast,
    this.defaultSaturation,
    this.colorBalance,
  );
}

enum AspectRatioMode {
  original('أصلي', null),
  reels('9:16 ريلز', 9 / 16),
  youtube('16:9 يوتيوب', 16 / 9),
  square('1:1 مربع', 1.0);

  final String label;
  final double? ratio;

  const AspectRatioMode(this.label, this.ratio);
}

enum StudioLens {
  trim('قص', Icons.content_cut_rounded),
  speed('سرعة', Icons.speed_rounded),
  color('ألوان', Icons.auto_awesome_rounded),
  audio('صوت', Icons.graphic_eq_rounded),
  frame('إطار', Icons.crop_rotate_rounded);

  final String label;
  final IconData icon;

  const StudioLens(this.label, this.icon);
}

class EditProject {
  final String videoPath;
  Duration videoDuration;
  Duration trimStart;
  Duration trimEnd;

  double speed;
  FilterPreset filterPreset;
  double brightness; // -0.4 to 0.4
  double contrast;   // 0.5 to 1.8
  double saturation; // 0.0 to 2.0

  int rotationQuarterTurns; // 0, 1, 2, 3
  bool flipHorizontal;
  AspectRatioMode aspectRatioMode;

  bool muteOriginal;
  double originalVolume; // 0.0 to 1.0
  String? musicPath;
  String? musicName;
  double musicVolume; // 0.0 to 1.0

  int exportHeight; // 720 or 1080

  EditProject({
    required this.videoPath,
    this.videoDuration = Duration.zero,
    this.trimStart = Duration.zero,
    this.trimEnd = Duration.zero,
    this.speed = 1.0,
    this.filterPreset = FilterPreset.original,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.saturation = 1.0,
    this.rotationQuarterTurns = 0,
    this.flipHorizontal = false,
    this.aspectRatioMode = AspectRatioMode.original,
    this.muteOriginal = false,
    this.originalVolume = 1.0,
    this.musicPath,
    this.musicName,
    this.musicVolume = 0.65,
    this.exportHeight = 1080,
  });

  void resetAll() {
    trimStart = Duration.zero;
    trimEnd = videoDuration;
    speed = 1.0;
    filterPreset = FilterPreset.original;
    brightness = 0.0;
    contrast = 1.0;
    saturation = 1.0;
    rotationQuarterTurns = 0;
    flipHorizontal = false;
    aspectRatioMode = AspectRatioMode.original;
    muteOriginal = false;
    originalVolume = 1.0;
    musicPath = null;
    musicName = null;
    musicVolume = 0.65;
  }

  void applyPreset(FilterPreset preset) {
    filterPreset = preset;
    brightness = preset.defaultBrightness;
    contrast = preset.defaultContrast;
    saturation = preset.defaultSaturation;
  }

  /// Live preview color matrix matching brightness, contrast & saturation
  List<double> buildPreviewColorMatrix() {
    final b = brightness * 255.0;
    final c = contrast;
    final t = (1.0 - c) * 128.0 + b;

    final s = saturation;
    const lumR = 0.2126;
    const lumG = 0.7152;
    const lumB = 0.0722;

    final sr = (1 - s) * lumR;
    final sg = (1 - s) * lumG;
    final sb = (1 - s) * lumB;

    // Subtle tint for cinematic/neon/golden presets in preview
    double rTint = 1.0;
    double gTint = 1.0;
    double bTint = 1.0;
    if (filterPreset == FilterPreset.cinematic) {
      rTint = 1.06;
      bTint = 0.93;
    } else if (filterPreset == FilterPreset.neonNight) {
      rTint = 0.96;
      gTint = 1.03;
      bTint = 1.12;
    } else if (filterPreset == FilterPreset.golden) {
      rTint = 1.10;
      gTint = 1.03;
      bTint = 0.88;
    }

    return <double>[
      c * (sr + s) * rTint, c * sg * rTint, c * sb * rTint, 0, t,
      c * sr * gTint, c * (sg + s) * gTint, c * sb * gTint, 0, t,
      c * sr * bTint, c * sg * bTint, c * (sb + s) * bTint, 0, t,
      0, 0, 0, 1, 0,
    ];
  }
}
