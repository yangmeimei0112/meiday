import 'package:flutter/material.dart';

class GlassmorphismStyles {
  /// Frosted glass decoration for cards, dialogs, and floating mini-panels
  static BoxDecoration glassDecoration({
    required BuildContext context,
    double borderRadius = 12.0,
    double opacity = 0.75,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF1E293B).withValues(alpha: opacity)
          : const Color(0xFFFFFFFF).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
          blurRadius: 16.0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
