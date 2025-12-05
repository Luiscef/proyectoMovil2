import 'package:cloud_firestore/cloud_firestore.dart';


class FirestoreService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<void> saveProfilePhotoUrl(String uid, String url) async {
    final docRef = firestore.collection('users').doc(uid);
    await docRef.set({'photoUrl': url}, SetOptions(merge: true));
  }

  Future<String?> getProfilePhotoUrl(String uid) async {
    final doc = await firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data();
      if (data != null && data['photoUrl'] is String) {
        return data['photoUrl'] as String;
      }
    }
    return null;
  }
}