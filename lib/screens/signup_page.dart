import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupPage
    extends
        StatefulWidget {
  const SignupPage({
    super.key,
  });

  @override
  State<
    SignupPage
  >
  createState() => _SignupPageState();
}

class _SignupPageState
    extends
        State<
          SignupPage
        > {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<
    void
  >
  signup() async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            "Account created!",
          ),
        ),
      );
      Navigator.pop(
        context,
      );
    } on FirebaseAuthException catch (
      e
    ) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.message ??
                "Error",
          ),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Sign Up",
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(
          16,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            ElevatedButton(
              onPressed: signup,
              child: const Text(
                "Sign Up",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
