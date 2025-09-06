import 'package:flutter/material.dart';

class AppColors {
  // Primary colors - Modern purple/blue gradient theme
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5); // Darker indigo
  static const Color secondary = Color(0xFF8B5CF6); // Purple
  static const Color accent = Color(0xFF06B6D4); // Cyan
  
  // Background colors
  static const Color background = Color(0xFF0F0F23); // Very dark blue
  static const Color surface = Color(0xFF1E1E3F); // Dark blue-purple
  static const Color cardBackground = Color(0xFF252547); // Lighter dark blue
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFE2E8F0); // Light gray
  static const Color textMuted = Color(0xFF94A3B8); // Muted gray
  
  // Status colors
  static const Color success = Color(0xFF10B981); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  
  // Gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Purple
  ];
  
  static const List<Color> accentGradient = [
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
  ];
  
  static const List<Color> backgroundGradient = [
    Color(0xFF0F0F23), // Very dark blue
    Color(0xFF1E1E3F), // Dark blue-purple
  ];
  
  // Gradient decorations
  static const LinearGradient primaryLinearGradient = LinearGradient(
    colors: primaryGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentLinearGradient = LinearGradient(
    colors: accentGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundLinearGradient = LinearGradient(
    colors: backgroundGradient,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Deprecated - Old red color for reference
  static const Color oldRed = Color(0xFF6366F1);
}
