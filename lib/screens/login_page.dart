import 'dart:io' show Platform;

import 'package:cineholmes/pages/upload_page.dart';
import 'package:cineholmes/screens/forget_page.dart';
import 'package:cineholmes/screens/signup_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final bool showBackButton;
  const LoginPage({super.key, this.showBackButton = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  // -------------------------
  // FRIENDLY ERROR MESSAGES
  // -------------------------
  String _friendlyEmailPasswordError(dynamic e) {
    // FirebaseAuthException is the "correct" case
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'wrong-password':
          return 'Incorrect password.';
        case 'user-not-found':
          return 'No account found with this email.';
        case 'invalid-email':
          return 'Invalid email format.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'invalid-credential':
          // sometimes shows for wrong password on newer SDKs
          return 'Incorrect email or password.';
        default:
          return e.message ?? 'Sign-in failed. Please try again.';
      }
    }

    // Some plugin/channel issues show as strange strings (like pigeon host api)
    final s = e.toString();
    if (s.contains('FirebaseAuthHostApi') || s.contains('pigeon')) {
      return 'Something went wrong. Please restart the app and try again.';
    }

    return 'Sign-in failed. Please try again.';
  }

  String _friendlyGoogleError(dynamic e) {
    final s = e.toString();

    // Common Google Sign-In config error
    if (s.contains('ApiException: 10')) {
      return 'Google Sign-In is not configured on this build yet. Please use email/password for now.';
    }

    if (s.toLowerCase().contains('network')) {
      return 'Network error. Please check your connection.';
    }

    return 'Google Sign-In failed. Please try again.';
  }

  // -------------------------
  // EMAIL/PASSWORD LOGIN
  // -------------------------
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("rememberMe", _rememberMe);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UploadPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyEmailPasswordError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------
  // GOOGLE SIGN-IN
  // -------------------------
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UploadPage()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyGoogleError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // -------------------------
  // FORGOT PASSWORD
  // -------------------------
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email address.")),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Email sent"),
          content: const Text("A password reset link has been sent to your email."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyEmailPasswordError(e))),
      );
    }
  }

  // -------------------------
  // UI HELPERS
  // -------------------------
  Widget _socialButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String text,
    bool enabled = true,
  }) {
    final VoidCallback? finalOnPressed = enabled ? onPressed : null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: finalOnPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(fontSize: 15, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6A0DAD),
          disabledBackgroundColor: Colors.white24,
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // -------------------------
  // BUILD
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => widget.showBackButton,
      child: Scaffold(
        appBar: widget.showBackButton
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              )
            : null,
        extendBodyBehindAppBar: true,
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
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Login",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Email",
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white12,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Overflow-safe row
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (val) =>
                                  setState(() => _rememberMe = val ?? false),
                              activeColor: Colors.deepPurpleAccent,
                              checkColor: Colors.white,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const Text(
                              "Remember Me",
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ForgotPage()),
                            );
                          },
                          child: const Text(
                            "Forgot password?",
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A0DAD),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "Sign In",
                              style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignUpPage()),
                        );
                      },
                      child: const Text(
                        "Don't have an account? Sign up",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Google (enabled)
                    _socialButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: Icons.g_mobiledata,
                      text: "Continue with Google",
                      enabled: !_isLoading,
                    ),

                    const SizedBox(height: 12),

                    // Facebook (Soon) disabled
                    _socialButton(
                      onPressed: null,
                      icon: Icons.facebook,
                      text: "Continue with Facebook (Soon)",
                      enabled: false,
                    ),

                    const SizedBox(height: 12),

                    // Apple (Soon) only on iOS, disabled
                    if (Platform.isIOS)
                      _socialButton(
                        onPressed: null,
                        icon: Icons.apple,
                        text: "Continue with Apple (Soon)",
                        enabled: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
