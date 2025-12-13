import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home_main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _showAiLogs = false;
  bool _autoOpenInfoPage = true;
  bool _showSnackbars = true;
  String _defaultTab = 'home';

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Instagram-style header
            _buildInstagramHeader(isDark),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // HEADER
                  Text(
                    'Settings',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tweak your CineHolmes experience.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // === APPEARANCE ===
                  _sectionTitle('Appearance', isDark),
                  const SizedBox(height: 8),
                  _glassCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          secondary: Icon(
                            isDark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: isDark ? Colors.amber : Colors.deepPurple,
                          ),
                          title: Text(
                            'Dark Theme',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Use dark mode for a cinematic, eye-friendly look.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          value: themeProvider.isDark,
                          onChanged: (_) => themeProvider.toggleTheme(),
                          activeThumbColor: Colors.deepPurpleAccent,
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          leading: Icon(
                            Icons.palette_outlined,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'Accent color',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Purple • (More colors coming soon)',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
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
                  _sectionTitle('App Preferences', isDark),
                  const SizedBox(height: 8),
                  _glassCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        // Default tab
                        ListTile(
                          leading: Icon(
                            Icons.home_work_outlined,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'Default start page',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            _defaultTab == 'home'
                                ? 'Home'
                                : _defaultTab == 'library'
                                    ? 'Library'
                                    : 'Upload',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          trailing: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _defaultTab,
                              dropdownColor: isDark
                                  ? const Color(0xFF1A1A1A)
                                  : Colors.white,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'home',
                                  child: Text(
                                    'Home',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'library',
                                  child: Text(
                                    'Library',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'upload',
                                  child: Text(
                                    'Upload',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
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
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          secondary: Icon(
                            Icons.play_circle_outline,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'Auto open details',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'After AI matches a title, open info page automatically.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          value: _autoOpenInfoPage,
                          onChanged: (value) {
                            setState(() => _autoOpenInfoPage = value);
                          },
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          secondary: Icon(
                            Icons.notifications_active_outlined,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'Show snackbars',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Keep small feedback messages like "Added to library ✅".',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          value: _showSnackbars,
                          onChanged: (value) {
                            setState(() => _showSnackbars = value);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // === AI & UPLOAD ===
                  _sectionTitle('AI & Upload', isDark),
                  const SizedBox(height: 8),
                  _glassCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          secondary: Icon(
                            Icons.smart_toy_outlined,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'Detailed AI logs',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Show more detailed status & error messages while analyzing.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          value: _showAiLogs,
                          onChanged: (value) {
                            setState(() => _showAiLogs = value);
                          },
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.history,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'Manage upload history',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Long-press items in History (Upload tab) to delete them.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
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
                  _sectionTitle('Account & About', isDark),
                  const SizedBox(height: 8),
                  _glassCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.person_outline,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'Manage account',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Edit your profile and password.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Open Profile tab to manage your account.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                        ListTile(
                          leading: Icon(
                            Icons.info_outline,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'About CineHolmes',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Cine detective powered by Gemini & TMDB.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'CineHolmes',
                              applicationVersion: 'v0.1.0 (alpha)',
                              applicationIcon:
                                  const Icon(Icons.movie_filter_outlined),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildInstagramHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6A0DAD), Color(0xFF9D4EDD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'CineHolmes',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pacifico',
                color: Colors.white,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _glassCard({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
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