// profile_drawer.dart - Profile drawer widget

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../screens/login_page.dart';
import '../home_main.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  final AuthService _authService = AuthService();
  User? _currentUser;

  // Avatar Assets
  final List<String> _avatarAssets = const [
    'assets/avatars/AAGRBT0C7xk_1765710192725.png',
    'assets/avatars/AAGRBT0C7xk_1765710192730.png',
    'assets/avatars/AAGRBT0C7xk_1765710388485.png',
    'assets/avatars/AAGRBT0C7xk_1765710388489.png',
    'assets/avatars/AAGRBT0C7xk_1765710388506.png',
    'assets/avatars/AAGRBT0C7xk_1765710568040.png',
    'assets/avatars/AAGRBT0C7xk_1765710568053.png',
    'assets/avatars/AAGRBT0C7xk_1765710568056.png',
  ];

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

  Future<void> _updateProfilePicture(String newAssetPath) async {
    try {
      await _currentUser?.updatePhotoURL(newAssetPath);
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Profile picture updated! ✅',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF6A0DAD),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAvatarSelectionDialog() {
    // Giriş kontrolü
    if (_currentUser == null) {
      _showSignInPrompt();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          "Select Profile Picture",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: _avatarAssets.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final assetPath = _avatarAssets[index];

              return GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await _updateProfilePicture(assetPath);
                },
                child: ClipOval(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      border: Border.all(color: Colors.white24, width: 1.0),
                    ),
                    child: Image.asset(assetPath, fit: BoxFit.cover),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    // Giriş kontrolü
    if (_currentUser == null) {
      _showSignInPrompt();
      return;
    }

    String currentPassword = '';
    String newPassword = '';
    String confirmPassword = '';
    String? errorMessage;
    final formKey = GlobalKey<FormState>();
    final dialogContext = context;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            "Change Password",
            style: TextStyle(color: Colors.white),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade700),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade300,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade300,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextFormField(
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    currentPassword = value;
                    if (errorMessage != null) {
                      setState(() => errorMessage = null);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: "Current Password",
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: "Enter current password",
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6A0DAD)),
                    ),
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
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => newPassword = value,
                  decoration: const InputDecoration(
                    labelText: "New Password",
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: "Enter new password",
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6A0DAD)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'New password is required';
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
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => confirmPassword = value,
                  decoration: const InputDecoration(
                    labelText: "Confirm New Password",
                    labelStyle: TextStyle(color: Colors.white70),
                    hintText: "Confirm new password",
                    hintStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF6A0DAD)),
                    ),
                  ),
                  validator: (value) {
                    if (value != newPassword) {
                      return 'Passwords do not match';
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A0DAD),
              ),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  showDialog(
                    context: dialogContext,
                    barrierDismissible: false,
                    builder: (BuildContext loadingContext) {
                      return Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  );

                  try {
                    final credential = EmailAuthProvider.credential(
                      email: email,
                      password: currentPassword,
                    );

                    await _currentUser?.reauthenticateWithCredential(
                      credential,
                    );
                    await _currentUser?.updatePassword(newPassword);

                    if (mounted) {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      Navigator.of(dialogContext, rootNavigator: true).pop();

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password updated! ✅',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Color(0xFF6A0DAD),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    String newErrorMessage = 'Unknown error';

                    if (e.code == 'wrong-password' ||
                        e.code == 'invalid-credential') {
                      newErrorMessage = 'Current password is incorrect.';
                    } else if (e.code == 'weak-password') {
                      newErrorMessage = 'Password is too weak';
                    } else if (e.code == 'requires-recent-login') {
                      newErrorMessage =
                          'Please log out and log in again for security.';
                    } else {
                      newErrorMessage = 'An error occurred: ${e.message}';
                    }

                    if (mounted) {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      setState(() {
                        errorMessage = newErrorMessage;
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.of(dialogContext, rootNavigator: true).pop();
                      setState(() {
                        errorMessage = 'An unexpected error occurred';
                      });

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            '❌ Error: $e',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text("Change"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignInPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange.shade300),
            const SizedBox(width: 12),
            const Text(
              'Sign In Required',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'You need to sign in to access this feature.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A0DAD),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    // Giriş kontrolü
    if (_currentUser == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();
      if (!mounted) return;

      // Sign out sonrası profil drawer'ı yenile
      setState(() {
        _currentUser = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out successfully'),
          backgroundColor: Color(0xFF6A0DAD),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kullanıcı giriş yapmamışsa farklı drawer göster
    if (_currentUser == null) {
      return Drawer(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6A0DAD).withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF6A0DAD),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            size: 60,
                            color: Color(0xFF6A0DAD),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Başlık
                        const Text(
                          'Not Signed In',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Alt yazı
                        const Text(
                          'Sign in to access your profile,\nsave history, and more',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Sign In butonu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context); // Drawer'ı kapat
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      'Login / Sign Up',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Kullanıcı giriş yapmışsa normal profil drawer'ı göster
    final photoURL = _currentUser?.photoURL;

    return Drawer(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Profile Picture
                  GestureDetector(
                    onTap: _showAvatarSelectionDialog,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: const Color(0xFF6A0DAD),
                          backgroundImage:
                              photoURL != null && photoURL.isNotEmpty
                              ? (photoURL.startsWith('http')
                                    ? NetworkImage(photoURL)
                                    : AssetImage(photoURL) as ImageProvider)
                              : null,
                          child: photoURL == null || photoURL.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF6A0DAD),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Username
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    email,
                    style: const TextStyle(fontSize: 14, color: Colors.white60),
                  ),
                ],
              ),
            ),

            // Options
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  // Change Password
                  if (isEmailPasswordUser)
                    ListTile(
                      leading: const Icon(
                        Icons.lock_outline,
                        color: Colors.white70,
                      ),
                      title: const Text(
                        'Change Password',
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: _showChangePasswordDialog,
                    ),

                  // Dark Theme Toggle
                  ListTile(
                    leading: const Icon(
                      Icons.dark_mode_outlined,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Dark Theme',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Switch(
                      value: Provider.of<ThemeProvider>(context).isDark,
                      onChanged: (_) {
                        Provider.of<ThemeProvider>(
                          context,
                          listen: false,
                        ).toggleTheme();
                      },
                      activeColor: const Color(0xFF6A0DAD),
                    ),
                  ),
                ],
              ),
            ),

            // Sign Out Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _signOut,
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
