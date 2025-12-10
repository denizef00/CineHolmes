import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home_main.dart'; // ThemeProvider buradan geliyor

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Sadece yerel / UI state (şimdilik gerçek fonksiyonlara bağlı değil)
  bool _showAiLogs = false;
  bool _autoOpenInfoPage = true;
  bool _showSnackbars = true;
  String _defaultTab = 'home'; // 'home' | 'library' | 'upload'

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // HEADER
        Text(
          'Settings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tweak your CineHolmes experience.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 20),

        // === APPEARANCE ===
        _sectionTitle('Appearance'),
        const SizedBox(height: 8),
        _glassCard(
          isDark: isDark,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                secondary: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? Colors.amber : Colors.deepPurple,
                ),
                title: const Text('Dark Theme'),
                subtitle: const Text(
                  'Use dark mode for a cinematic, eye-friendly look.',
                ),
                value: themeProvider.isDark,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeThumbColor: Colors.deepPurpleAccent,
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Accent color'),
                subtitle: const Text('Purple • (More colors coming soon)'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _accentDot(const Color(0xFF6A0DAD)),
                    const SizedBox(width: 6),
                    _accentDot(Colors.blueGrey, isSelected: false),
                    const SizedBox(width: 6),
                    _accentDot(Colors.teal, isSelected: false),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // === APP PREFERENCES ===
        _sectionTitle('App Preferences'),
        const SizedBox(height: 8),
        _glassCard(
          isDark: isDark,
          child: Column(
            children: [
              // Default tab
              ListTile(
                leading: const Icon(Icons.home_work_outlined),
                title: const Text('Default start page'),
                subtitle: Text(
                  _defaultTab == 'home'
                      ? 'Home'
                      : _defaultTab == 'library'
                          ? 'Library'
                          : 'Upload',
                ),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _defaultTab,
                    items: const [
                      DropdownMenuItem(
                        value: 'home',
                        child: Text('Home'),
                      ),
                      DropdownMenuItem(
                        value: 'library',
                        child: Text('Library'),
                      ),
                      DropdownMenuItem(
                        value: 'upload',
                        child: Text('Upload'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _defaultTab = value;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Default page preference saved (UI only for now).',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                secondary: const Icon(Icons.play_circle_outline),
                title: const Text('Auto open details'),
                subtitle: const Text(
                  'After AI matches a title, open info page automatically.',
                ),
                value: _autoOpenInfoPage,
                onChanged: (value) {
                  setState(() => _autoOpenInfoPage = value);
                  // TODO: UploadPage’de bu tercihi kullanabilirsin.
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Show snackbars'),
                subtitle: const Text(
                  'Keep small feedback messages like “Added to library ✅”.',
                ),
                value: _showSnackbars,
                onChanged: (value) {
                  setState(() => _showSnackbars = value);
                  // Şimdilik sadece UI state; istersen global bir SettingsProvider’a taşırsın.
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // === AI & UPLOAD ===
        _sectionTitle('AI & Upload'),
        const SizedBox(height: 8),
        _glassCard(
          isDark: isDark,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                secondary: const Icon(Icons.smart_toy_outlined),
                title: const Text('Detailed AI logs'),
                subtitle: const Text(
                  'Show more detailed status & error messages while analyzing.',
                ),
                value: _showAiLogs,
                onChanged: (value) {
                  setState(() => _showAiLogs = value);
                  // UploadPage içinde status mesajlarını bu flag’e göre detaylandırabilirsin.
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Manage upload history'),
                subtitle: const Text(
                  'Long-press items in History (Upload tab) to delete them.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Go to Upload tab → long-press on posters to delete.',
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // === ACCOUNT & ABOUT ===
        _sectionTitle('Account & About'),
        const SizedBox(height: 8),
        _glassCard(
          isDark: isDark,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Manage account'),
                subtitle: const Text('Edit your profile and password.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // HomeMain’de zaten Profile tab’in var; kullanıcı orayı açabilir.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Open Profile tab to manage your account.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('About CineHolmes'),
                subtitle: const Text(
                  'Cine detective powered by Gemini & TMDB.',
                ),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'CineHolmes',
                    applicationVersion: 'v0.1.0 (alpha)',
                    applicationIcon: const Icon(Icons.movie_filter_outlined),
                    children: const [
                      SizedBox(height: 8),
                      Text(
                        'CineHolmes helps you identify movies and TV shows '
                        'from short clips using AI (Google Gemini) and TMDB data.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'This product uses the TMDB API but is not endorsed or '
                        'certified by TMDB.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // --- HELPER WIDGETS ---

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _glassCard({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _accentDot(Color color, {bool isSelected = true}) {
    return Container(
      width: isSelected ? 16 : 14,
      height: isSelected ? 16 : 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: isSelected ? Colors.white : Colors.transparent,
          width: 2,
        ),
      ),
    );
  }
}
