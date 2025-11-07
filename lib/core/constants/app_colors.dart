import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFE50914); // Netflix red as primary
  static const Color background = Color(0xFF141414); 
  static const Color surface = Color(0xFF1F1F1F);
  static const Color accent = Color(0xFFE50914); 
  static const Color muted = Color(0xFF9A9A9A);
  static const Color text = Colors.white;
  
  // Additional shades for primary color
  static const Color primaryLight = Color(0xFFFF5252);
  static const Color primaryDark = Color(0xFFB71C1C);
  
  // Semantic colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  // Gradient colors
  static const Gradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE50914), Color(0xFFFF5252)],
  );
}