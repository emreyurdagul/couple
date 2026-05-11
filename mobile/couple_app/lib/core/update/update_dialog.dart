import 'package:flutter/material.dart';

import 'version_service.dart';

/// Update bulunduğunda gösterilir. mandatory=true ise dismiss edilemez,
/// "Sonra" butonu görünmez.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({
    super.key,
    required this.info,
    required this.onDownloadAndInstall,
  });

  final VersionInfo info;

  /// Returns true if install was triggered (dialog can close); false on cancel
  /// or error. Sırasıyla download + installApk çağırır; UI'yı tekrarlanabilir
  /// duruma getirebilmek için exception throw etmez.
  final Future<bool> Function(void Function(double) onProgress)
      onDownloadAndInstall;

  static Future<void> show(
    BuildContext context, {
    required VersionInfo info,
    required Future<bool> Function(void Function(double)) onDownloadAndInstall,
  }) =>
      showDialog<void>(
        context: context,
        barrierDismissible: !info.mandatory,
        builder: (_) => PopScope(
          canPop: !info.mandatory,
          child: UpdateDialog(
            info: info,
            onDownloadAndInstall: onDownloadAndInstall,
          ),
        ),
      );

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  double? _progress;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final ok = await widget.onDownloadAndInstall((p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!ok && mounted) {
        setState(() {
          _error = 'Yükleyici açılamadı. Bilinmeyen kaynaklardan yükleme '
              'iznini onayla ve tekrar dene.';
          _progress = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'İndirme başarısız: $e';
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final mb = (info.sizeBytes / (1024 * 1024)).toStringAsFixed(1);
    final downloading = _progress != null;

    return AlertDialog(
      title: Text(info.mandatory
          ? 'Zorunlu güncelleme'
          : 'Yeni sürüm ${info.latestVersionName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info.mandatory
                ? 'Devam edebilmek için yeni sürümü yüklemen gerek.'
                : 'Yeni bir sürüm hazır. Şimdi güncellemek ister misin?',
          ),
          const SizedBox(height: 8),
          Text('Boyut: $mb MB',
              style: Theme.of(context).textTheme.bodySmall),
          if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(info.releaseNotes!,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _progress!.clamp(0.0, 1.0)),
            const SizedBox(height: 4),
            Text('${(_progress! * 100).clamp(0, 100).toStringAsFixed(0)}%'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        if (!info.mandatory && !downloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Sonra'),
          ),
        FilledButton(
          onPressed: downloading ? null : _start,
          child: Text(_error != null ? 'Tekrar dene' : 'Güncelle'),
        ),
      ],
    );
  }
}
