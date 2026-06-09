import 'dart:io';

import 'package:flutter/material.dart';

class SmartImage extends StatelessWidget {
  final String? path;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? fallback;

  const SmartImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallback,
  });

  bool get _isRemote {
    final value = path ?? '';
    return value.startsWith('http://') || value.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (path == null || path!.isEmpty) {
      child = fallback ?? const SizedBox.shrink();
    } else if (_isRemote) {
      child = Image.network(
        path!,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return fallback ?? const SizedBox.shrink();
        },
      );
    } else {
      child = Image.file(
        File(path!),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return fallback ?? const SizedBox.shrink();
        },
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: child,
      );
    }

    return child;
  }
}