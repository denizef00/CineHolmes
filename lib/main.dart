import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:cineholmes/screens/login_page.dart';
import 'package:cineholmes/pages/upload_page.dart';
import 'package:cineholmes/home_main.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    // ✅ Sadece ThemeProvider kullanıyoruz
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
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
      home: const AuthWrapper(),
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
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6A0DAD),
              ),
            ),
          );
        }

        // 2. Hata kontrolü
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        // 3. Kullanıcı durumunu kontrol et
        if (snapshot.hasData && snapshot.data != null) {
          // ✅ Kullanıcı giriş yapmış - Ana sayfaya git
          print('✅ User logged in: ${snapshot.data!.email}');
          return const UploadPage();
        } else {
          // ❌ Kullanıcı giriş yapmamış - Login sayfasına git
          print('❌ No user logged in');
          return const LoginPage();
        }
      },
    );
  }
}