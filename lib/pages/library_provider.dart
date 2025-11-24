// lib/providers/library_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LibraryProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _libraryItems = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get libraryItems => _libraryItems;
  bool get isLoading => _isLoading;

  // Kullanıcının kütüphane koleksiyonuna erişim
  CollectionReference? get _userLibrary {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _firestore.collection('users').doc(user.uid).collection('library');
  }

  // Kütüphaneyi Firestore'dan yükle
  Future<void> loadLibrary() async {
    final user = _auth.currentUser;
    if (user == null) {
      _libraryItems = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('library')
          .get();

      _libraryItems = snapshot.docs.map((doc) {
        final data = doc.data();
        data['firestoreId'] = doc.id; // Firestore document ID'sini de sakla
        return data;
      }).toList();
    } catch (e) {
      print('Error loading library: $e');
      _libraryItems = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Kütüphanede var mı kontrol et
  bool isInLibrary(int id) {
    return _libraryItems.any((item) => item['id'] == id);
  }

  // Kütüphaneye ekle (Firestore'a kaydet)
  Future<void> addToLibrary(Map<String, dynamic> item) async {
    if (_userLibrary == null) {
      print('No user logged in');
      return;
    }

    // Zaten ekliyse ekleme
    if (isInLibrary(item['id'])) {
      print('Item already in library');
      return;
    }

    try {
      // Firestore'a ekle
      final docRef = await _userLibrary!.add({
        'id': item['id'],
        'title': item['title'],
        'poster': item['poster'],
        'rating': item['rating'],
        'year': item['year'],
        'type': item['type'],
        'addedAt': FieldValue.serverTimestamp(), // Eklenme tarihi
      });

      // Local listeye de ekle
      final newItem = Map<String, dynamic>.from(item);
      newItem['firestoreId'] = docRef.id;
      _libraryItems.add(newItem);

      notifyListeners();
      print('✅ Added to library: ${item['title']}');
    } catch (e) {
      print('❌ Error adding to library: $e');
      rethrow;
    }
  }

  // Kütüphaneden çıkar (Firestore'dan sil)
  Future<void> removeFromLibrary(int id) async {
    if (_userLibrary == null) return;

    try {
      // Local listede bul
      final item = _libraryItems.firstWhere(
        (item) => item['id'] == id,
        orElse: () => {},
      );

      if (item.isEmpty || item['firestoreId'] == null) {
        print('Item not found in library');
        return;
      }

      // Firestore'dan sil
      await _userLibrary!.doc(item['firestoreId']).delete();

      // Local listeden çıkar
      _libraryItems.removeWhere((item) => item['id'] == id);

      notifyListeners();
      print('✅ Removed from library: ${item['title']}');
    } catch (e) {
      print('❌ Error removing from library: $e');
      rethrow;
    }
  }

  // Toggle (varsa çıkar, yoksa ekle)
  Future<void> toggleLibrary(Map<String, dynamic> item) async {
    if (isInLibrary(item['id'])) {
      await removeFromLibrary(item['id']);
    } else {
      await addToLibrary(item);
    }
  }

  // Kullanıcı çıkış yaptığında kütüphaneyi temizle
  void clearLibrary() {
    _libraryItems = [];
    notifyListeners();
  }
}
