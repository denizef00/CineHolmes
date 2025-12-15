import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ✅ ThemeProvider - Artık sadece bu kullanılıyor
class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;

  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }

  ThemeData get themeData {
    return ThemeData(
      brightness: _isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: _isDark ? Colors.black : Colors.white,
      primaryColor: const Color(0xFF6A0DAD),
      colorScheme: ColorScheme(
        brightness: _isDark ? Brightness.dark : Brightness.light,
        primary: const Color(0xFF6A0DAD),
        onPrimary: Colors.white,
        secondary: const Color(0xFF9D4EDD),
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: _isDark ? const Color(0xFF1C1C1E) : Colors.white,
        onSurface: _isDark ? Colors.white : Colors.black87,
      ),
      cardColor: _isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade100,
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: _isDark ? Colors.white : Colors.black87),
        bodyMedium: TextStyle(color: _isDark ? Colors.white70 : Colors.black54),
        titleLarge: TextStyle(
          color: _isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: IconThemeData(
        color: _isDark ? Colors.white : Colors.black87,
      ),
    );
  }
}

// ℹ️ NOT: Artık HomeScreen, PageView, BottomNavigationBar kullanılmıyor
// Yeni yapıda direkt NewUploadPage ana sayfa olarak kullanılıyor
// Bu dosya sadece ThemeProvider için tutuluyor

/* 
ESKI KOD (Artık kullanılmıyor):
- HomeScreen
- _HomeScreenState
- PageView with 5 pages
- BottomNavigationBar
- OnePageOnlyScrollPhysics

YENİ YAPI:
- main.dart → AuthWrapper → NewUploadPage
- NewUploadPage içinde:
  - Sol Drawer (History)
  - Sağ Drawer (Profile + Settings)
  - Ana ekran (Video upload & AI detection)
*/