import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart' show HomePage;
import 'pages/library_page.dart' show LibraryPage;
import 'pages/upload_page.dart' show UploadPage;
import 'pages/profile_page.dart' show ProfilePage;
import 'pages/settings_page.dart' show SettingsPage;

// ✅ Swipe sadece komşu sayfaya (±1) gitsin diye custom physics
class OnePageOnlyScrollPhysics extends ScrollPhysics {
  const OnePageOnlyScrollPhysics({super.parent});

  @override
  OnePageOnlyScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return OnePageOnlyScrollPhysics(parent: buildParent(ancestor));
  }

  double _page(ScrollMetrics position) {
    return position.pixels / position.viewportDimension;
  }

  double _pixels(ScrollMetrics position, double page) {
    return page * position.viewportDimension;
  }

  @override
  double getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    // PageView mantığı: hedef "sayfa"yı hesapla ama maksimum ±1 izin ver
    final double currentPage = _page(position);
    int currentIndex = currentPage.round();

    int targetIndex = currentIndex;

    // velocity belirginse bir sonraki/önceki sayfaya git
    if (velocity > tolerance.velocity) {
      targetIndex = currentIndex + 1;
    } else if (velocity < -tolerance.velocity) {
      targetIndex = currentIndex - 1;
    } else {
      // yavaş sürükleme: en yakın sayfaya otur
      targetIndex = currentPage.round();
    }

    // ✅ güvenlik: sadece komşu sayfa (±1)
    if (targetIndex > currentIndex + 1) targetIndex = currentIndex + 1;
    if (targetIndex < currentIndex - 1) targetIndex = currentIndex - 1;

    // bounds clamp
    final double targetPixels = _pixels(position, targetIndex.toDouble());
    return targetPixels.clamp(position.minScrollExtent, position.maxScrollExtent);
  }
}

// Instagram-style app title widget
class CineHolmesTitle extends StatelessWidget {
  const CineHolmesTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'CineHolmes',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87,
      ),
    );
  }
}

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

class CineHolmesApp extends StatelessWidget {
  const CineHolmesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'CineHolmes',
            theme: themeProvider.themeData,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  bool _isAnimating = false;

  final List<Widget> _pages = const [
    HomePage(),
    LibraryPage(),
    UploadPage(),
    ProfilePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _currentPageIndexSafe() {
    if (!_pageController.hasClients) return _selectedIndex;
    final p = _pageController.page;
    if (p == null) return _selectedIndex;
    return p.round();
  }

  Future<void> _onItemTapped(int index) async {
    if (index == _selectedIndex) return;
    if (_isAnimating) return;

    final current = _currentPageIndexSafe();
    final diff = (index - current).abs();

    setState(() => _selectedIndex = index);

    // ✅ Uzak sekme: aradakileri göstermeden zıpla
    if (diff > 1) {
      _pageController.jumpToPage(index);
      return;
    }

    // ✅ Komşu sekme: animasyon
    _isAnimating = true;
    try {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _isAnimating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;

    return Theme(
      data: themeProvider.themeData,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: PageView(
          controller: _pageController,
          // ✅ Swipe sadece komşu sayfaya gitsin
          physics: const OnePageOnlyScrollPhysics(parent: PageScrollPhysics()),
          onPageChanged: (index) {
            if (!mounted) return;
            setState(() => _selectedIndex = index);
          },
          children: _pages,
        ),
        bottomNavigationBar: _buildModernBottomBar(isDark),
      ),
    );
  }

  Widget _buildModernBottomBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 65,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Stack(
              children: [
                // Sliding indicator
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: _getIndicatorPosition(),
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6A0DAD).withOpacity(0.2),
                          const Color(0xFF9D4EDD).withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF6A0DAD).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                // Icons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.home_rounded, 'Home', isDark),
                    _buildNavItem(1, Icons.video_library_rounded, 'Library', isDark),
                    _buildNavItem(2, Icons.add_circle_rounded, 'Upload', isDark),
                    _buildNavItem(3, Icons.person_rounded, 'Profile', isDark),
                    _buildNavItem(4, Icons.settings_rounded, 'Settings', isDark),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getIndicatorPosition() {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32) / 5; // padding 16+16
    return (_selectedIndex * itemWidth) + (itemWidth - 60) / 2;
  }

  Widget _buildNavItem(int index, IconData icon, String label, bool isDark) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque, // ✅ boşlukta da yakala
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: 70, // ✅ hit area büyüdü
        height: 55,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: Icon(
                icon,
                size: isSelected ? 28 : 24,
                color: isSelected
                    ? const Color(0xFF6A0DAD)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              style: TextStyle(
                fontSize: isSelected ? 11 : 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF6A0DAD)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
