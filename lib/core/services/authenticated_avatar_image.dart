import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'api_client.dart';

class AuthenticatedAvatarImage extends StatefulWidget {
  const AuthenticatedAvatarImage({
    super.key,
    this.avatarUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.fallback,
  });

  final String? avatarUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? fallback;

  @override
  State<AuthenticatedAvatarImage> createState() =>
      _AuthenticatedAvatarImageState();
}

class _AuthenticatedAvatarImageState extends State<AuthenticatedAvatarImage> {
  late Future<Uint8List> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = ApiClient.fetchAvatarImage();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.avatarUrl != widget.avatarUrl) {
      _imageFuture = ApiClient.fetchAvatarImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.avatarUrl == null || widget.avatarUrl!.trim().isEmpty) {
      return widget.fallback ?? const Icon(Icons.person_rounded);
    }

    return FutureBuilder<Uint8List>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                widget.fallback ?? const Icon(Icons.person_rounded),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        return widget.fallback ?? const Icon(Icons.person_rounded);
      },
    );
  }
}
