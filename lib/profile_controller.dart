
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'storage_service.dart';
import 'firestore_service.dart';

class ProfileController {
  final StorageService _storage = StorageService();
  final FirestoreService _firestore = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  String imageUrl =
      'https://preview.redd.it/i-tried-to-remake-walter-white-skateboarding-v0-nvdd0uwwo4ne1.jpg?width=736&format=pjpg&auto=webp&s=d59d1fbdd478865f12c2c4beb76457691925885b';

  File? localImage;
  bool uploading = false;

  ProfileController();

  Future<String> _getProfileDocId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'public_profile';
  }

  Future<String?> loadSavedProfilePhoto() async {
    final String docId = await _getProfileDocId();
    final String? savedUrl = await _firestore.getProfilePhotoUrl(docId);
    if (savedUrl != null) {
      imageUrl = savedUrl;
      return savedUrl;
    }
    return null;
  }

  Future<String?> pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (picked == null) return null;

      final File file = File(picked.path);
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
}
