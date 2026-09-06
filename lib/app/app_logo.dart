import 'package:flutter/material.dart';

/// The app's mark — a sparkle on the brand teal squircle, matching the
/// launcher icon (`android/.../mipmap-*/ic_launcher.png`,
/// `windows/runner/resources/app_icon.ico`) so the in-app branding and the
/// icon the user actually taps are the same image, not just similarly
/// colored shapes.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64, this.borderRadius});

  final double size;

  /// Defaults to ~22% of [size] to match the launcher icon's own corner
  /// radius (224/1024 of the source art).
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
