import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:projectv1/screens/login_page.dart';
import '../services/auth_service.dart'; // 👈 AuthService import edildi

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _obscurePassword = true;
  User? _currentUser;
  final AuthService _authService = AuthService(); // 👈 AuthService eklendi

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Firebase'den güncel kullanıcıyı çek
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload(); // Firebase'den yenile

    setState(() {
      _currentUser = FirebaseAuth.instance.currentUser;
    });
  }

  // 👇 Firebase'den email al
  String get email => _currentUser?.email ?? "Email not found.";

  // 👇 Firebase'den kullanıcı adı al
  String get username {
    // Display name varsa onu kullan
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.isNotEmpty) {
      return _currentUser!.displayName!;
    }
    // Yoksa email'in @ öncesi kısmını kullan
    return _currentUser?.email?.split('@')[0] ?? "User";
  }

  // 👇 Şifre (Firebase şifre döndürmez, placeholder)
  String get password => "••••••••";

  // Giriş yöntemi kontrolü
  bool get isEmailPasswordUser {
    if (_currentUser == null) return false;
    return _currentUser!.providerData.any(
      (info) => info.providerId == 'Password',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profil fotoğrafı
          CircleAvatar(
            radius: 50,
            backgroundImage: _currentUser?.photoURL != null
                ? NetworkImage(_currentUser!.photoURL!)
                : null,
            child: _currentUser?.photoURL == null
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
          const SizedBox(height: 20),

          // Mail
          ListTile(leading: const Icon(Icons.email), title: Text(email)),

          // Username
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(username),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showChangeUsernameDialog,
            ),
          ),

          // Şifre (sadece email/password kullanıcıları için)
          if (isEmailPasswordUser)
            ListTile(
              leading: const Icon(Icons.lock),
              title: GestureDetector(
                onTap: _showChangePasswordDialog,
                child: Text(
                  _obscurePassword ? "••••••••" : password,
                  style: const TextStyle(letterSpacing: 2),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                      // Firebase şifre gösteremez uyarısı
                      if (!_obscurePassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password cannot be shown for security reasons.',
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        // 2 saniye sonra tekrar gizle
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            setState(() {
                              _obscurePassword = true;
                            });
                          }
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _showChangePasswordDialog,
                  ),
                ],
              ),
            ),

          // Eğer Google/Facebook/Apple ile giriş yaptıysa bilgi göster
          if (!isEmailPasswordUser)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(
                'You have successfully logged in with social media.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ),

          const SizedBox(height: 30),

          // 👇 LOGOUT BUTONU
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // 👇 LOGOUT FONKSİYONU
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

          // 🔴 Burada login sayfasına yönlendirme yapıyoruz
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => LoginPage(),
            ), // giriş ekranının adı
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

  // 👇 Kullanıcı adı değiştirme
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
                // Dialogu kapat
                Navigator.pop(context);

                try {
                  // Firebase'de display name güncelle
                  await _currentUser?.updateDisplayName(newUsername);

                  // Kullanıcıyı yeniden yükle
                  await _loadUserData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Username Updated ✅'),
                      ),
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

  // 👇 Şifre değiştirme (sadece email/password kullanıcıları için)
  void _showChangePasswordDialog() {
    if (!isEmailPasswordUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password cannot be changed for social media accounts.'),
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
                  // 1. Kullanıcıyı mevcut şifresiyle yeniden doğrula
                  final credential = EmailAuthProvider.credential(
                    email: email,
                    password: currentPassword,
                  );
                  await _currentUser?.reauthenticateWithCredential(credential);

                  // 2. Yeni şifreyi güncelle
                  await _currentUser?.updatePassword(newPassword);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password updated.✅'),
                      ),
                    );
                  }
                } on FirebaseAuthException catch (e) {
                  String errorMessage = 'Error';
                  if (e.code == 'wrong-password') {
                    errorMessage = 'Incorrect current password.';
                  } else if (e.code == 'weak-password') {
                    errorMessage = 'The password you entered is too weak';
                  } else if (e.code == 'requires-recent-login') {
                    errorMessage = 'For security reasons, please re-authenticate.';
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

/*import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _obscurePassword = true;

  String email = "cineholmes@example.com";
  String username = "cineholmes_user";
  String password =
      "12345678"; // örnek, gerçek projede güvenli şekilde tutulmalı

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profil fotoğrafı
         /* CircleAvatar(
            radius: 50,
            backgroundImage: AssetImage(
              //stock pp eklenmeli
              'assets/images/baseapp.png',
            ), // placeholder resim
          ),*/
          const SizedBox(height: 20),

          // Mail
          ListTile(leading: const Icon(Icons.email), title: Text(email)),

          // Username
          ListTile(leading: const Icon(Icons.person), title: Text(username)),

          // Şifre
          ListTile(
            leading: const Icon(Icons.lock),
            title: GestureDetector(
              onTap: () {
                // Şifre değiştirme dialogu
                _showChangePasswordDialog();
              },
              child: Text(
                _obscurePassword ? "********" : password,
                style: const TextStyle(letterSpacing: 2),
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    String newPassword = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: TextField(
          obscureText: true,
          onChanged: (value) {
            newPassword = value;
          },
          decoration: const InputDecoration(hintText: "Enter the new password"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelled"),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPassword.isNotEmpty) {
                setState(() {
                  password = newPassword;
                  _obscurePassword = true;
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}*/
