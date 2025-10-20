import 'package:flutter/material.dart';

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
          CircleAvatar(
            radius: 50,
            backgroundImage: AssetImage(
              //stock pp eklenmeli
              'assets/images/baseapp.png',
            ), // placeholder resim
          ),
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
}
