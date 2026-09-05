import 'package:flutter/material.dart';
import 'package:shiclash/core/update/update_service.dart';

class UpdateInstallDialog extends StatefulWidget {
  const UpdateInstallDialog({
    super.key,
    required this.service,
    required this.info,
  });

  final UpdateService service;
  final UpdateInfo info;

  @override
  State<UpdateInstallDialog> createState() => _UpdateInstallDialogState();
}

class _UpdateInstallDialogState extends State<UpdateInstallDialog>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _waitingForPermission = false;
  UpdateProgress? _progress;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForPermission && !_busy) {
      _waitingForPermission = false;
      _install();
    }
  }

  Future<void> _install() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.downloadAndInstall(
        widget.info,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      if (mounted) Navigator.pop(context, true);
    } on UpdatePermissionException catch (error) {
      if (mounted) {
        setState(() {
          _waitingForPermission = true;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return AlertDialog(
      title: const Text('Update Shiclash'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Versi ${widget.info.latestVersion} akan diunduh dan dipasang langsung dari aplikasi.',
          ),
          if (progress != null) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(value: progress.fraction),
            const SizedBox(height: 8),
            Text(_progressLabel(progress)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Nanti'),
        ),
        FilledButton.icon(
          onPressed: _busy || _waitingForPermission ? null : _install,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.system_update_alt),
          label: Text(_busy ? 'Memproses…' : 'Pasang update'),
        ),
      ],
    );
  }

  String _progressLabel(UpdateProgress progress) {
    switch (progress.phase) {
      case UpdatePhase.downloading:
        final downloaded = _megabytes(progress.receivedBytes);
        final total = progress.totalBytes;
        return total == null
            ? 'Mengunduh… $downloaded MB'
            : 'Mengunduh… $downloaded / ${_megabytes(total)} MB';
      case UpdatePhase.verifying:
        return 'Memverifikasi keamanan APK…';
      case UpdatePhase.installing:
        return 'Membuka installer Android…';
    }
  }

  String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}
