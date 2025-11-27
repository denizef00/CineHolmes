import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:projectv1/screens/login_page.dart';
import 'package:projectv1/home_main.dart';
import 'package:projectv1/pages/library_provider.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => LibraryProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CineHolmes',
      home: const AuthWrapper(), // ✅ AuthWrapper burada
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Bağlantı durumunu kontrol et
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Hata kontrolü (opsiyonel)
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        // 3. Kullanıcı durumunu kontrol et
        if (snapshot.hasData && snapshot.data != null) {
          // ✅ Kullanıcı giriş yapmış - Kütüphaneyi yükle
          print('✅ User logged in: ${snapshot.data!.email}');

          // Kütüphaneyi yükle
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<LibraryProvider>(context, listen: false).loadLibrary();
          });

          return const CineHolmesApp();
        } else {
          // ❌ Kullanıcı giriş yapmamış - Kütüphaneyi temizle
          print('❌ No user logged in');

          // Kütüphaneyi temizle
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Provider.of<LibraryProvider>(context, listen: false).clearLibrary();
          });

          return const LoginPage();
        }
      },
    );
  }
}
