import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import '../models/edit_project.dart';

class ExportResult {
  final bool success;
  final String? outputPath;
  final String message;

  ExportResult({
    required this.success,
    this.outputPath,
    required this.message,
  });
}

class FfmpegEngine {
  static String _fmtSec(Duration d) {
    return (d.inMilliseconds / 1000.0).toStringAsFixed(3);
  }

  /// Chains FFmpeg atempo filters cleanly for any speed in [0.25, 4.0]
  static String _buildAtempoChain(double speed) {
    final filters = <String>[];
    double remaining = speed;
    while (remaining > 2.0) {
      filters.add('atempo=2.0');
      remaining /= 2.0;
    }
    while (remaining < 0.5) {
      filters.add('atempo=0.5');
      remaining /= 0.5;
    }
    filters.add('atempo=${remaining.toStringAsFixed(3)}');
    return filters.join(',');
  }

  static Future<ExportResult> exportProject({
    required EditProject project,
    required void Function(double progress) onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath = '${tempDir.path}/PULSE_$ts.mp4';

    final startSec = _fmtSec(project.trimStart);
    final endDuration = project.trimEnd > project.trimStart
        ? project.trimEnd
        : project.videoDuration;
    final clipMs = (endDuration - project.trimStart).inMilliseconds;
    final expectedOutMs = (clipMs / project.speed).clamp(500.0, 36000000.0);

    // 1. Build video filter chain
    final vFilters = <String>[];

    if (project.rotationQuarterTurns == 1) {
      vFilters.add('transpose=1');
    } else if (project.rotationQuarterTurns == 2) {
      vFilters.add('hflip,vflip');
    } else if (project.rotationQuarterTurns == 3) {
      vFilters.add('transpose=2');
    }

    if (project.flipHorizontal) {
      vFilters.add('hflip');
    }

    // Aspect ratio smart center crop
    if (project.aspectRatioMode == AspectRatioMode.reels) {
      vFilters.add("crop='min(iw,ih*9/16)':'min(ih,iw*16/9)'");
    } else if (project.aspectRatioMode == AspectRatioMode.youtube) {
      vFilters.add("crop='min(iw,ih*16/9)':'min(ih,iw*9/16)'");
    } else if (project.aspectRatioMode == AspectRatioMode.square) {
      vFilters.add("crop='min(iw,ih)':'min(iw,ih)'");
    }

    // Resolution scale with guaranteed even dimensions for libx264
    final maxH = project.exportHeight;
    vFilters.add("scale=-2:'min($maxH,ih)':flags=lanczos");
    vFilters.add("scale=trunc(iw/2)*2:trunc(ih/2)*2");

    // Color grading
    final hasColorEdits = project.brightness.abs() > 0.005 ||
        (project.contrast - 1.0).abs() > 0.005 ||
        (project.saturation - 1.0).abs() > 0.005;
    if (hasColorEdits) {
      vFilters.add(
        'eq=brightness=${project.brightness.toStringAsFixed(2)}'
        ':contrast=${project.contrast.toStringAsFixed(2)}'
        ':saturation=${project.saturation.toStringAsFixed(2)}',
      );
    }
    if (project.filterPreset.colorBalance != null) {
      vFilters.add('colorbalance=${project.filterPreset.colorBalance}');
    }

    // Speed ramp
    if ((project.speed - 1.0).abs() > 0.01) {
      vFilters.add('setpts=PTS/${project.speed.toStringAsFixed(3)}');
    }

    final vChain = vFilters.join(',');
    final hasMusic = project.musicPath != null && project.musicPath!.isNotEmpty;

    final args = <String>[
      '-y',
      '-ss', startSec,
      '-to', _fmtSec(endDuration),
      '-i', project.videoPath,
    ];

    if (hasMusic) {
      args.addAll(['-stream_loop', '-1', '-i', project.musicPath!]);
    }

    // Filter complex & audio mapping
    if (hasMusic && !project.muteOriginal) {
      final atempo = _buildAtempoChain(project.speed);
      final vVol = project.originalVolume.toStringAsFixed(2);
      final mVol = project.musicVolume.toStringAsFixed(2);
      final fc = '[0:v]$vChain[vout];'
          '[0:a]$atempo,volume=$vVol[a0];'
          '[1:a]volume=$mVol[a1];'
          '[a0][a1]amix=inputs=2:duration=first:dropout_transition=2[aout]';
      args.addAll(['-filter_complex', fc, '-map', '[vout]', '-map', '[aout]']);
    } else if (hasMusic && project.muteOriginal) {
      final mVol = project.musicVolume.toStringAsFixed(2);
      final fc = '[0:v]$vChain[vout];[1:a]volume=$mVol[aout]';
      args.addAll([
        '-filter_complex', fc,
        '-map', '[vout]',
        '-map', '[aout]',
        '-shortest',
      ]);
    } else if (project.muteOriginal) {
      args.addAll(['-vf', vChain, '-an']);
    } else {
      args.addAll(['-vf', vChain]);
      final aFilters = <String>[];
      if ((project.speed - 1.0).abs() > 0.01) {
        aFilters.add(_buildAtempoChain(project.speed));
      }
      if ((project.originalVolume - 1.0).abs() > 0.02) {
        aFilters.add('volume=${project.originalVolume.toStringAsFixed(2)}');
      }
      if (aFilters.isNotEmpty) {
        args.addAll(['-af', aFilters.join(',')]);
      }
    }

    args.addAll([
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-crf', '21',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-movflags', '+faststart',
      outPath,
    ]);

    try {
      final session = await FFmpegKit.executeWithArgumentsAsync(
        args,
        null,
        null,
        (Statistics stats) {
          final t = stats.getTime();
          if (t > 0) {
            final pct = (t / expectedOutMs).clamp(0.0, 0.98);
            onProgress(pct);
          }
        },
      );

      // Poll until session completes
      while (await session.getReturnCode() == null) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final rc = await session.getReturnCode();
      if (ReturnCode.isSuccess(rc)) {
        onProgress(1.0);
        await Gal.putVideo(outPath, album: 'PULSE');
        return ExportResult(
          success: true,
          outputPath: outPath,
          message: 'تم تصدير الفيديو وحفظه في ألبوم PULSE بالمعرض!',
        );
      } else if (ReturnCode.isCancel(rc)) {
        return ExportResult(success: false, message: 'تم إلغاء التصدير.');
      } else {
        final logs = await session.getFailStackTrace() ??
            await session.getOutput() ??
            'خطأ غير معروف';
        // Fallback retry without original audio if source clip had no audio track
        if (!project.muteOriginal &&
            (logs.contains('Stream specifier') ||
                logs.contains('matches no streams'))) {
          final copy = EditProject(
            videoPath: project.videoPath,
            videoDuration: project.videoDuration,
            trimStart: project.trimStart,
            trimEnd: project.trimEnd,
            speed: project.speed,
            filterPreset: project.filterPreset,
            brightness: project.brightness,
            contrast: project.contrast,
            saturation: project.saturation,
            rotationQuarterTurns: project.rotationQuarterTurns,
            flipHorizontal: project.flipHorizontal,
            aspectRatioMode: project.aspectRatioMode,
            muteOriginal: true,
            musicPath: project.musicPath,
            musicVolume: project.musicVolume,
            exportHeight: project.exportHeight,
          );
          return exportProject(project: copy, onProgress: onProgress);
        }
        return ExportResult(
          success: false,
          message: 'تعذر تصدير الفيديو. تأكد من المساحة المتاحة وجرّب مرة أخرى.',
        );
      }
    } catch (e) {
      if (File(outPath).existsSync()) {
        try {
          File(outPath).deleteSync();
        } catch (_) {}
      }
      return ExportResult(
        success: false,
        message: 'حدث خطأ أثناء المعالجة: $e',
      );
    }
  }

  static Future<void> cancelAll() async {
    await FFmpegKit.cancel();
  }
}
