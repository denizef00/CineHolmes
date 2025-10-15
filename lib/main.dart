import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:projectv1/screens/login_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login Demo',
      home: LoginPage(),
    );
  }
}

/*
username
login hatırlama
google facebook apple girişi
daha iyi ui
mail kontrolü
şifre sistemi
güçlü şifre önerme
*/
