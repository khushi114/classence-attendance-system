import 'package:flutter/material.dart';

/// Centralized color palette for Smart Attendance System
class AppColors {
  AppColors._();

  // ── Primary ──
  static const Color deepBlue = Color(0xFF1E3A8A);
  static const Color royalBlue = Color(0xFF2563EB);
  static const Color lightBlue = Color(0xFF3B82F6);

  // ── Accent ──
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color orange = Color(0xFFF59E0B);
  static const Color orangeLight = Color(0xFFFBBF24);

  // ── Background ──
  static const Color backgroundLight = Color(0xFFF3F4F6);
  static const Color backgroundDark = Color(0xFF111827);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1F2937);

  // ── Text ──
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Status ──
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Borders & Dividers ──
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderColor = border;
  static const Color divider = Color(0xFFF3F4F6);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [royalBlue, deepBlue],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [emerald, Color(0xFF059669)],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange, Color(0xFFD97706)],
  );

  // ── Glassmorphism ──
  static Color glassWhite = Colors.white.withValues(alpha: 0.15);
  static Color glassBorder = Colors.white.withValues(alpha: 0.2);
  static Color glassOverlay = Colors.white.withValues(alpha: 0.08);
}
