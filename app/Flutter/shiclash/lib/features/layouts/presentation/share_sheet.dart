import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shiclash/core/theme/app_theme.dart';
import 'package:shiclash/features/layouts/data/share_api.dart';

/// Uploads a snapshot, then hands back the link.
///
/// Sharing is a copy, not a publish: the layout on this phone stays the one
/// being edited, and this link keeps showing what was sent. That is stated in
/// the sheet so nobody expects a shared base to follow later edits.
Future<void> showShareSheet(
  BuildContext context, {
  required String title,
  required Map<String, dynamic> layout,
  ShareApi? api,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareDialog(title: title, layout: layout, api: api),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog({required this.title, required this.layout, this.api});

  final String title;
  final Map<String, dynamic> layout;
  final ShareApi? api;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  late final ShareApi _api = widget.api ?? ShareApi();
  String? _url;
  String? _error;
  bool _busy = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _upload();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.share(
        title: widget.title,
        layout: widget.layout,
      );
      if (mounted) setState(() => _url = result.url);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _url!));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bagikan layout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Mengirim salinan ke server…'),
                ],
              ),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.brass))
          else ...[
            SelectableText(
              _url!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tautan ini berisi salinan beku. Layout di HP-mu tetap bisa diedit, '
              'dan perubahannya tidak ikut ke tautan ini — bagikan lagi untuk '
              'membuat tautan versi terbaru.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        if (_error != null)
          FilledButton(
            onPressed: _busy ? null : _upload,
            child: const Text('Coba lagi'),
          )
        else if (!_busy)
          FilledButton.icon(
            onPressed: _copy,
            icon: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 17,
            ),
            label: Text(_copied ? 'Tersalin' : 'Salin tautan'),
          ),
      ],
    );
  }
}
