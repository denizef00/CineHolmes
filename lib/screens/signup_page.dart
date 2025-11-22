import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _usernameController = TextEditingController(); // 👈 YENİ EKLEME
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _signUp() async {
    // Şifre kontrolü
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Şifreler aynı değil ❌")));
      return;
    }

    // Kullanıcı adı kontrolü
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Kullanıcı adı gerekli ❌")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. Firebase'de hesap oluştur
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Kullanıcı adını (display name) set et
      await userCredential.user?.updateDisplayName(_usernameController.text.trim());
      await userCredential.user?.reload();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Kayıt başarılı ✅")));

        Navigator.pop(context); // login sayfasına dön
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Hata: ${e.message}';
      
      // Türkçe hata mesajları
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Bu email zaten kullanımda';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Şifre çok zayıf (en az 6 karakter)';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Geçersiz email adresi';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    
  }

  // 👇 YENİ FONKSİYONLAR - GOOGLE (username ile)
  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && mounted) {
        // Google zaten display name ve photo sağlıyor
        // AuthWrapper otomatik olarak home'a yönlendirecek
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 👇 YENİ FONKSİYONLAR - FACEBOOK
  Future<void> _handleFacebookSignUp() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithFacebook();
      if (userCredential != null && mounted) {
        // AuthWrapper otomatik olarak home'a yönlendirecek
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 👇 YENİ FONKSİYONLAR - APPLE
  Future<void> _handleAppleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithApple();
      if (userCredential != null && mounted) {
        // AuthWrapper otomatik olarak home'a yönlendirecek
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 59, 46, 105),
              Color.fromARGB(255, 37, 30, 63),
              Color(0xFF1E1E2C),
              Colors.black87,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Create Account 🧩",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 👇 YENİ: Username field
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Username",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      prefixIcon: const Icon(Icons.person, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Email",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      prefixIcon: const Icon(Icons.email, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Password",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Confirm Password",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : ElevatedButton(
                          onPressed: _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.9),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Sign Up"),
                        ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "I have an account!",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // BUTONLARA FONKSİYON BAĞLANDI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: IconButton(
                          onPressed: _isLoading ? null : _handleGoogleSignUp,
                          icon: const FaIcon(
                            FontAwesomeIcons.google,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: IconButton(
                          onPressed: _isLoading ? null : _handleFacebookSignUp,
                          icon: const FaIcon(
                            FontAwesomeIcons.facebook,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: IconButton(
                          onPressed: _isLoading ? null : _handleAppleSignUp,
                          icon: const FaIcon(
                            FontAwesomeIcons.apple,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose(); // 👈 Dispose ekle
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}






















/*import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_service.dart'; // 👈 YENİ EKLEME

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService(); // 👈 YENİ EKLEME
  bool _isLoading = false;

  Future<void> _signUp() async {
    // Şifre kontrolü
    if (_passwordController.text.trim() !=
        _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Şifreler aynı değil ❌")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Kayıt başarılı ✅")));

      Navigator.pop(context); // login sayfasına dön
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: ${e.message}")));
    } finally {
      setState(() => _isLoading = false);
    }
  }
  // 👇 YENİ FONKSİYONLAR - GOOGLE
  Future<void> _handleGoogleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && mounted) {
        // AuthWrapper otomatik olarak home'a yönlendirecek
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 👇 YENİ FONKSİYONLAR - FACEBOOK
  Future<void> _handleFacebookSignUp() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithFacebook();
      if (userCredential != null && mounted) {
        // AuthWrapper otomatik olarak home'a yönlendirecek
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 👇 YENİ FONKSİYONLAR - APPLE
  Future<void> _handleAppleSignUp() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithApple();
      if (userCredential != null && mounted) {
        // AuthWrapper otomatik olarak home'a yönlendirecek
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 59, 46, 105),
              Color.fromARGB(255, 37, 30, 63),
              Color(0xFF1E1E2C),
              Colors.black87,
            ],
            begin: Alignment.topCenter, // üstten başla
            end: Alignment.bottomCenter, // alta doğru koyulaş
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Create Account 🧩",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      hintText: "Email",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      prefixIcon: const Icon(Icons.email, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Password",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Confirm Password",
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.white,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : ElevatedButton(
                          onPressed: _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.9),
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Sign Up"),
                        ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "I have an account!",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Üç ikon butonu (login sayfasıyla aynı)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: IconButton(
                          onPressed: () {},
                          icon: const FaIcon(
                            FontAwesomeIcons.google,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: IconButton(
                          onPressed: () {},
                          icon: const FaIcon(
                            FontAwesomeIcons.facebook,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: IconButton(
                          onPressed: () {},
                          icon: const FaIcon(
                            FontAwesomeIcons.apple,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}*/

/*
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> signup() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Account created!")));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: signup, child: const Text("Sign Up")),
          ],
        ),
      ),
    );
  }
}*/
