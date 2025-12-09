import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'storage_service.dart';
import 'firestore_service.dart';

class ProfileController {
  final StorageService _storage = StorageService();
  final FirestoreService _firestore = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestoreRaw = FirebaseFirestore.instance;

  String imageUrl =
      'https://preview.redd.it/i-tried-to-remake-walter-white-skateboarding-v0-nvdd0uwwo4ne1.jpg?width=736&format=pjpg&auto=webp&s=d59d1fbdd478865f12c2c4beb76457691925885b';

  File? localImage;
  bool uploading = false;

  bool darkMode = false;
  bool notificationsEnabled = false;

  String displayName = '';
  String email = '';

  ProfileController();

  Future<String> _getProfileDocId() async {
    final user = _auth.currentUser;
    return user?.uid ?? 'public_profile';
  }

  Future<void> loadSavedProfile() async {
    final String docId = await _getProfileDocId();
    final String? savedUrl = await _firestore.getProfilePhotoUrl(docId);
    if (savedUrl != null) {
      imageUrl = savedUrl;
    }
    try {
      final doc = await _firestoreRaw.collection('users').doc(docId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          if (data['theme'] is String) {
            darkMode = (data['theme'] as String) == 'dark';
          }
          if (data['notificationsEnabled'] is bool) {
            notificationsEnabled = data['notificationsEnabled'] as bool;
          }
          if (data['displayName'] is String) {
            displayName = data['displayName'] as String;
          }
          if (data['email'] is String) {
            email = data['email'] as String;
          }
        }
      }
    } catch (_) {}
    final user = _auth.currentUser;
    if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        displayName = user.displayName!;
      }
      if (user.email != null && user.email!.isNotEmpty) {
        email = user.email!;
      }
    }
  }

  Future<String?> pickAndUploadImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return null;
      final file = File(picked.path);
      localImage = file;
      uploading = true;
      final String? url = await _storage.uploadImage(file, 'profile_images');
      if (url != null) {
        final docId = await _getProfileDocId();
        await _firestore.saveProfilePhotoUrl(docId, url);
        imageUrl = url;
        localImage = null;
        return url;
      } else {
        return null;
      }
    } catch (e) {
      rethrow;
    } finally {
      uploading = false;
    }
  }

  Future<void> updateProfile({
    required String name,
    required String email,
  }) async {
    final uid = await _getProfileDocId();
    await _firestoreRaw.collection('users').doc(uid).set({
      'displayName': name,
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final user = _auth.currentUser;
    if (user != null && user.uid != 'public_profile') {
      try {
        await user.updateDisplayName(name);
      } catch (_) {}
      if ((user.email ?? '') != email) {
        try {
          await user.updateEmail(email);
        } on FirebaseAuthException {
          rethrow;
        }
      }
    }
    displayName = name;
    this.email = email;
  }

  Future<bool> reauthenticateAndUpdateEmail(
    String currentPassword,
    String newEmail,
  ) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return false;
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    try {
      await user.reauthenticateWithCredential(credential);
      await user.updateEmail(newEmail);
      final uid = await _getProfileDocId();
      await _firestoreRaw.collection('users').doc(uid).set({
        'email': newEmail,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      email = newEmail;
      return true;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    darkMode = isDark;
    final uid = await _getProfileDocId();
    await _firestoreRaw.collection('users').doc(uid).set({
      'theme': isDark ? 'dark' : 'light',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> toggleNotifications(bool enable) async {
    notificationsEnabled = enable;
    final uid = await _getProfileDocId();
    await _firestoreRaw.collection('users').doc(uid).set({
      'notificationsEnabled': enable,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
