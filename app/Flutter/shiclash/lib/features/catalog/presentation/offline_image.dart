import 'package:flutter/material.dart';
import 'package:shiclash/features/catalog/data/offline_store.dart';

/// Drop-in replacement for `Image.network` that prefers a downloaded copy.
///
/// Every artwork in the app goes through this, so enabling offline data does
/// not mean revisiting a dozen screens — and a building whose file is missing
/// still loads over the network instead of showing a hole.
class OfflineImage extends StatelessWidget {
  const OfflineImage(
    this.url, {
    this.fit,
    this.width,
    this.height,
    this.filterQuality = FilterQuality.medium,
    this.errorBuilder,
    this.loadingBuilder,
    super.key,
  });

  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: OfflineStore.instance.imageProvider(url),
      fit: fit,
      width: width,
      height: height,
      filterQuality: filterQuality,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
    );
  }
}
