import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart' show HomePage;
import 'pages/library_page.dart' show LibraryPage;
import 'pages/upload_page.dart' show UploadPage;
import 'pages/profile_page.dart' show ProfilePage;
import 'pages/settings_page.dart' show SettingsPage;


class ThemeProvider extends ChangeNotifier {
  bool isDark = true;

  void toggleTheme() {
    isDark = !isDark;
    notifyListeners();
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
            theme: themeProvider.isDark
                ? ThemeData.dark().copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: Colors.deepPurpleAccent.shade100,
                      secondary: Colors.purpleAccent,
                      surface: const Color(0xFF1E1E2C),
                    ),
                    scaffoldBackgroundColor: const Color(0xFF121212),
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Color(0xFF1E1E2C),
                      foregroundColor: Colors.white,
                      centerTitle: true,
                    ),
                    bottomNavigationBarTheme: BottomNavigationBarThemeData(
                      backgroundColor: const Color(0xFF1E1E2C),
                      selectedItemColor: Colors.deepPurpleAccent.shade100,
                      unselectedItemColor: Colors.grey,
                    ),
                  )
                : ThemeData.light().copyWith(
                    primaryColor: Colors.deepPurple,
                    appBarTheme: const AppBarTheme(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      centerTitle: true,
                    ),
                    bottomNavigationBarTheme:
                        const BottomNavigationBarThemeData(
                          selectedItemColor: Colors.deepPurple,
                          unselectedItemColor: Colors.grey,
                        ),
                  ),
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

  final List<Widget> _pages =  [
    const HomePage(),
    const LibraryPage(),
    const UploadPage(),
    const ProfilePage(),
    const SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CineHolmes ')),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home Page'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Library'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add Video',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/home_page.dart';
import 'pages/library_page.dart';
import 'pages/upload_page.dart';
import 'pages/profile_page.dart';
import 'pages/settings_page.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const CineHolmesApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  bool isDark = true;

  void toggleTheme() {
    isDark = !isDark;
    notifyListeners();
  }
}

class CineHolmesApp extends StatelessWidget {
  const CineHolmesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Cine Holmes',
          theme: themeProvider.isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: Colors.deepPurpleAccent.shade100,
                    secondary: Colors.purpleAccent,
                    surface: const Color(0xFF1E1E2C),
                    background: const Color(0xFF121212),
                  ),
                  scaffoldBackgroundColor: const Color(0xFF121212),
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Color(0xFF1E1E2C),
                    foregroundColor: Colors.white,
                    centerTitle: true,
                  ),
                  bottomNavigationBarTheme: BottomNavigationBarThemeData(
                    backgroundColor: const Color(0xFF1E1E2C),
                    selectedItemColor: Colors.deepPurpleAccent.shade100,
                    unselectedItemColor: Colors.grey,
                  ),
                )
              : ThemeData.light().copyWith(
                  primaryColor: Colors.deepPurple,
                  appBarTheme: const AppBarTheme(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    centerTitle: true,
                  ),
                  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                    selectedItemColor: Colors.deepPurple,
                    unselectedItemColor: Colors.grey,
                  ),
                ),
          home: const HomeScreen(),
        );
      },
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

  final List<Widget> _pages = const [
    HomePage(),
    LibraryPage(),
    UploadPage(),
    ProfilePage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cine Holmes 🎬'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home Page'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Add Video'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}*/
