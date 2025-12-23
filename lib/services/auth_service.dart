import 'dart:convert';
import 'dart:math';
import 'dart:io' show Platform;

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // -------------------------
  // GOOGLE
  // -------------------------
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  // -------------------------
  // FACEBOOK
  // -------------------------
  Future<UserCredential?> signInWithFacebook() async {
    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );

    if (result.status != LoginStatus.success) return null;

    final token = result.accessToken;
    if (token == null) return null;

    final credential = FacebookAuthProvider.credential(token.tokenString);
    return _auth.signInWithCredential(credential);
  }

  // -------------------------
  // APPLE
  // -------------------------
  Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    // iOS/macOS: native
    if (Platform.isIOS || Platform.isMacOS) {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      return _auth.signInWithCredential(oauthCredential);
    }

    // Android: web flow (Service ID + Redirect URI .env'de olmalı)
    final serviceId = dotenv.env['APPLE_SERVICE_ID'];
    final redirectUri = dotenv.env['APPLE_REDIRECT_URI'];

    if (serviceId == null || redirectUri == null) {
      throw Exception(
        "Android Apple Sign-In için .env içine APPLE_SERVICE_ID ve APPLE_REDIRECT_URI eklemelisin.",
      );
    }

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
      webAuthenticationOptions: WebAuthenticationOptions(
        clientId: serviceId,
        redirectUri: Uri.parse(redirectUri),
      ),
    );

    final oauthCredential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    return _auth.signInWithCredential(oauthCredential);
  }

  // -------------------------
  // SIGN OUT  ✅ (SENDE EKSİK OLAN)
  // -------------------------
  Future<void> signOut() async {
    // Google oturumu varsa kapat
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    // Facebook oturumu varsa kapat
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}

    // Firebase oturumunu kapat (en önemlisi bu)
    await _auth.signOut();
  }

  // -------------------------
  // Helpers (nonce)
  // -------------------------
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
