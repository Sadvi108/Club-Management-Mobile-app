import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A failed or empty photo has the same initials fallback as the React Native app.
class MemberAvatar extends StatelessWidget {
  final String name, url, localPhoto;
  final double size, radius;
  final Color foreground, background;
  final IconData? fallbackIcon;
  const MemberAvatar(
      {super.key,
      required this.name,
      this.fallbackIcon,
      this.url = '',
      this.localPhoto = '',
      this.size = 52,
      this.radius = 26,
      this.foreground = Colors.white,
      this.background = const Color(0x40FFFFFF)});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();
    final fallback = ColoredBox(
        color: background,
        child: Center(
            child: fallbackIcon != null
                ? Icon(fallbackIcon, size: size * .5, color: foreground)
                : Text(initials.isEmpty ? '?' : initials,
                    style: TextStyle(
                        color: foreground,
                        fontSize: size * .35,
                        fontWeight: FontWeight.w800))));
    Widget photo = fallback;
    if (localPhoto.isNotEmpty) {
      try {
        photo = Image.memory(base64Decode(localPhoto),
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
      } catch (_) {/* use initials */}
    } else if (url.isNotEmpty) {
      photo = CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallback,
          errorWidget: (_, __, ___) => fallback);
    }
    return SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(radius), child: photo));
  }
}
