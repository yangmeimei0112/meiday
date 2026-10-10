import 'package:flutter/material.dart';

class AppColors {
  // Brand Primaries
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color secondary = accent;

  // Track 1: Anchored Events (Solid, immutable commitments)
  static const Color anchorEvent = Color(0xFF2563EB); // Deep Blue
  static const Color anchorEventBorder = Color(0xFF1D4ED8);

  // Track 2: Flexible Tasks (Bordered, negotiable time blocks)
  static const Color flexibleTask = Color(0xFF8B5CF6); // Purple
  static const Color flexibleTaskFillLight = Color(0x1F8B5CF6);
  static const Color flexibleTaskFillDark = Color(0x338B5CF6);

  // Workload Capacity Bar Threshold Colors (PRD §2)
  static const Color capacitySafe = Color(0xFF10B981); // Emerald (<=6h)
  static const Color capacityWarning = Color(0xFFF59E0B); // Amber (6h-8h)
  static const Color capacityOverloaded = Color(0xFFEF4444); // Red (>8h)

  // Status Color Aliases
  static const Color success = capacitySafe;
  static const Color warning = capacityWarning;
  static const Color danger = capacityOverloaded;

  // Calendar Space Default Palettes (PRD §3)
  static const Color spacePersonal = Color(0xFF6366F1); // Indigo
  static const Color spacePartner = Color(0xFFEC4899); // Rose/Pink
  static const Color spaceFamily = Color(0xFFF59E0B); // Amber
  static const Color spaceWork = Color(0xFF06B6D4); // Cyan/Teal

  // Dark Theme Background & Surfaces
  static const Color darkBackground = Color(0xFF0F172A); // Slate 900
  static const Color darkSurface = Color(0xFF1E293B); // Slate 800
  static const Color darkSurfaceElevated = Color(0xFF334155); // Slate 700
  static const Color darkBorder = Color(0xFF334155);

  // Light Theme Background & Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9); // Slate 100
  static const Color lightBorder = Color(0xFFE2E8F0);
}
