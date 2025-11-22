// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '329648345045-l4ggeonelcjtq3jknbqiu4ttc59vmhbu.apps.googleusercontent.com'
  );

  // Mevcut kullanıcı
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google ile giriş
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google hesabı seçimi
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // Kullanıcı iptal etti
        return null;
      }

      // Google authentication detayları
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Firebase credential oluştur
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase'e giriş yap
      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Google girişinde bir hata oluştu: $e';
    }
  }

  // Facebook ile giriş
  Future<UserCredential?> signInWithFacebook() async {
    try {
      // Facebook login dialog
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.success) {
        // Access token al
        final AccessToken accessToken = result.accessToken!;

        // Firebase credential oluştur
        final OAuthCredential credential = 
            FacebookAuthProvider.credential(accessToken.tokenString);

        // Firebase'e giriş yap
        final userCredential = await _auth.signInWithCredential(credential);
        return userCredential;
      } else if (result.status == LoginStatus.cancelled) {
        return null;
      } else {
        throw 'Facebook girişi başarısız: ${result.message}';
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Facebook girişinde bir hata oluştu: $e';
    }
  }

  // Apple ile giriş
  Future<UserCredential?> signInWithApple() async {
    try {
      // Apple Sign-In isteği
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // OAuth credential oluştur
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Firebase'e giriş yap
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw 'Apple girişi başarısız: ${e.message}';
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Apple girişinde bir hata oluştu: $e';
    }
  }

  // Email/Password ile kayıt
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Kayıt sırasında bir hata oluştu: $e';
    }
  }

  // Email/Password ile giriş
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Giriş sırasında bir hata oluştu: $e';
    }
  }

  // Şifre sıfırlama
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Şifre sıfırlama e-postası gönderilemedi: $e';
    }
  }

  // Çıkış yap
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
        FacebookAuth.instance.logOut(),
      ]);
    } catch (e) {
      throw 'Çıkış yapılırken bir hata oluştu: $e';
    }
  }

  // Firebase Auth hatalarını Türkçe mesajlara çevir
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'too-many-requests':
        return 'Çok fazla deneme yaptınız. Lütfen daha sonra tekrar deneyin.';
      case 'operation-not-allowed':
        return 'Bu işlem şu anda kullanılamıyor.';
      case 'account-exists-with-different-credential':
        return 'Bu e-posta başka bir yöntemle kayıtlı. Lütfen o yöntemi kullanın.';
      default:
        return 'Bir hata oluştu: ${e.message}';
    }
  }
}