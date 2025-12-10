import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 📋 Email kopyalamak için
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cineholmes/screens/login_page.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _currentUser;
  final AuthService _authService = AuthService();

  bool _loading = true; // 🔹 Yüklenme durumu

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    setState(() {
      _currentUser = FirebaseAuth.instance.currentUser;
      _loading = false;
    });
  }

  String get email => _currentUser?.email ?? "Email not found.";

  String get username {
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.isNotEmpty) {
      return _currentUser!.displayName!;
    }
    return _currentUser?.email?.split('@')[0] ?? "User";
  }

  bool get isEmailPasswordUser {
    if (_currentUser == null) return false;
    return _currentUser!.providerData.any(
      (info) => info.providerId == 'password',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off, size: 60),
              const SizedBox(height: 12),
              const Text(
                "No user is currently logged in.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text("Go to Login"),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 🔹 HEADER (gradient + avatar + username + email + chip)
          _buildProfileHeader(theme),

          const SizedBox(height: 24),

          // 🔹 ACCOUNT CARD
          _buildAccountCard(theme),

          const SizedBox(height: 16),

          // 🔹 SECURITY CARD
          _buildSecurityCard(theme),

          const SizedBox(height: 30),

          // 🔹 LOGOUT BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // 🔹 HEADER
  Widget _buildProfileHeader(ThemeData theme) {
    final gradientColors = [
      const Color(0xFF6A0DAD),
      const Color(0xFF9D4EDD),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        children: [
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 34,
              backgroundImage: _currentUser?.photoURL != null
                  ? NetworkImage(_currentUser!.photoURL!)
                  : null,
              backgroundColor: Colors.white.withOpacity(0.1),
              child: _currentUser?.photoURL == null
                  ? const Icon(Icons.person, size: 34, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          // İsim + email + chip
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Chip(
                      label: Text(
                        isEmailPasswordUser
                            ? 'Email & Password'
                            : 'Social Login',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 ACCOUNT CARD
  Widget _buildAccountCard(ThemeData theme) {
    final cardColor =
        theme.colorScheme.surface.withOpacity(theme.brightness == Brightness.dark ? 0.9 : 1.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(
            theme.brightness == Brightness.dark ? 0.05 : 0.08,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.4 : 0.1,
            ),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              "Account",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 8),

          // Email Row
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text("Email"),
            subtitle: Text(email),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: email));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Email copied to clipboard."),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ),

          // Username Row
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text("Username"),
            subtitle: Text(username),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showChangeUsernameDialog,
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 SECURITY CARD
  Widget _buildSecurityCard(ThemeData theme) {
    final cardColor =
        theme.colorScheme.surface.withOpacity(theme.brightness == Brightness.dark ? 0.9 : 1.0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(
            theme.brightness == Brightness.dark ? 0.05 : 0.08,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.4 : 0.1,
            ),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              "Security",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 8),

          if (isEmailPasswordUser)
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text("Change Password"),
              subtitle:
                  const Text("Update your account password securely."),
              onTap: _showChangePasswordDialog,
              trailing: const Icon(Icons.chevron_right),
            )
          else
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("Password Managed Externally"),
              subtitle: const Text(
                "You signed in with a social provider. Please manage your password from your Google / Apple / provider account.",
              ),
            ),
        ],
      ),
    );
  }

  // 🔹 LOGOUT
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        await _authService.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully logged out.')),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => LoginPage(),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Logout Error: $e')));
        }
      }
    }
  }

  // 🔹 USERNAME DİYALOĞU
  void _showChangeUsernameDialog() {
    String newUsername = username;
    final controller = TextEditingController(text: username);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Username"),
        content: TextField(
          controller: controller,
          onChanged: (value) {
            newUsername = value;
          },
          decoration: const InputDecoration(hintText: "New Username"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newUsername.isNotEmpty && newUsername != username) {
                Navigator.pop(context);
                try {
                  await _currentUser?.updateDisplayName(newUsername);
                  await _loadUserData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Username Updated ✅')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // 🔹 PASSWORD DİYALOĞU
  void _showChangePasswordDialog() {
    if (!isEmailPasswordUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password cannot be changed for social media accounts.',
          ),
        ),
      );
      return;
    }

    String currentPassword = "";
    String newPassword = "";
    String confirmPassword = "";
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                obscureText: true,
                onChanged: (value) => currentPassword = value,
                decoration: const InputDecoration(
                  labelText: "Current Password",
                  hintText: "Enter your current password.",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Current password is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                onChanged: (value) => newPassword = value,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  hintText: "Enter your new password",
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'A new password is required';
                  }
                  if (value.length < 6) {
                    return 'Password must be 6 characters minimum';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                onChanged: (value) => confirmPassword = value,
                decoration: const InputDecoration(
                  labelText: "Confirm New Password",
                  hintText: "Verify New Password",
                ),
                validator: (value) {
                  if (value != newPassword) {
                    return 'Passwords mismatch';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final credential = EmailAuthProvider.credential(
                    email: email,
                    password: currentPassword,
                  );
                  await _currentUser?.reauthenticateWithCredential(credential);
                  await _currentUser?.updatePassword(newPassword);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated.✅')),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  String errorMessage = 'Error';
                  if (e.code == 'wrong-password') {
                    errorMessage = 'Incorrect current password.';
                  } else if (e.code == 'weak-password') {
                    errorMessage = 'The password you entered is too weak';
                  } else if (e.code == 'requires-recent-login') {
                    errorMessage =
                        'For security reasons, please re-authenticate.';
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(errorMessage)));
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            child: const Text("Change"),
          ),
        ],
      ),
    );
  }
}
