import 'package:flutter/material.dart';

/// Paleta de la app. Cualquier color de marca se toma de acá en lugar de
/// repetir el valor hexadecimal en cada pantalla.
abstract final class AppColors {
  /// Violeta de marca: botones principales y semilla del ColorScheme.
  static const primary = Color(0xFF6C63FF);
  static const primaryLight = Color(0xFF8B85FF);

  /// Turquesa: respuestas correctas y acciones secundarias.
  static const teal = Color(0xFF4ECDC4);
  static const tealDark = Color(0xFF1A535C);

  /// Rosa: respuestas incorrectas y acento (generador con IA).
  static const pink = Color(0xFFFF6584);

  /// Rojo oscuro: texto de la respuesta incorrecta en modo claro.
  static const darkRed = Color(0xFFA3001B);

  /// Amarillo: logros y recordatorios.
  static const amber = Color(0xFFFFBC42);

  /// Fondos de los temas claro y oscuro.
  static const lightBackground = Color(0xFFF5F5FA);
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
}
