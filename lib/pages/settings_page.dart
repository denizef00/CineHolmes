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
                    child: SwitchListTile(
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
                  ),

                  const SizedBox(height: 20),

                  // === APP PREFERENCES ===
                  _sectionTitle('App Preferences', isDark),
                  const SizedBox(height: 8),
                  _glassCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        // Auto Open Details
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          secondary: Icon(
                            Icons.open_in_new_outlined,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'Auto-open details',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Open info page right after AI identifies a movie.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          value: _autoOpenInfoPage,
                          onChanged: (value) {
                            setState(() {
                              _autoOpenInfoPage = value;
                            });
                          },
                          activeThumbColor: Colors.deepPurpleAccent,
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                        ),
                        // Snackbar notifications
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          secondary: Icon(
                            Icons.notifications_outlined,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          title: Text(
                            'Snackbar notifications',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'Show quick messages for actions like adding to library.',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          value: _showSnackbars,
                          onChanged: (value) {
                            setState(() {
                              _showSnackbars = value;
                            });
                          },
                          activeThumbColor: Colors.deepPurpleAccent,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // === DEVELOPER ===
                  _sectionTitle('Developer', isDark),
                  const SizedBox(height: 8),
                  _glassCard(
                    isDark: isDark,
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      secondary: Icon(
                        Icons.code_outlined,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      title: Text(
                        'Show AI debug logs',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        'See what the AI is saying under the hood.',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      value: _showAiLogs,
                      onChanged: (value) {
                        setState(() {
                          _showAiLogs = value;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _showAiLogs
                                  ? 'AI logs will be printed to console.'
                                  : 'AI logs will be hidden.',
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: const Color(0xFF6A0DAD),
                          ),
                        );
                      },
                      activeThumbColor: Colors.deepPurpleAccent,
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
                              SnackBar(
                                content: const Text(
                                    'Open Profile tab to manage your account.'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF6A0DAD),
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
}