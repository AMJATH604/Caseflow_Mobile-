import 'package:flutter/material.dart';

import '../services/storage_links.dart';

/// `Image.network` for links that may point at a private storage bucket.
///
/// Resolves the stored link through [StorageLinks.resolve] first, so the image
/// keeps loading after the bucket is made private. Links to public buckets and
/// other sites load exactly as `Image.network` would.
class SecureNetworkImage extends StatefulWidget {
  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  const SecureNetworkImage(
    this.url, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  State<SecureNetworkImage> createState() => _SecureNetworkImageState();
}

class _SecureNetworkImageState extends State<SecureNetworkImage> {
  late Future<String> _resolved;

  @override
  void initState() {
    super.initState();
    _resolved = StorageLinks.resolve(widget.url);
  }

  @override
  void didUpdateWidget(covariant SecureNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resolved = StorageLinks.resolve(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolved,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Image.network(
          snapshot.data!,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          errorBuilder: widget.errorBuilder,
          loadingBuilder: widget.loadingBuilder,
        );
      },
    );
  }
}
