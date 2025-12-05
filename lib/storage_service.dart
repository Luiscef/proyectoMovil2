import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  
  final FirebaseStorage storage = FirebaseStorage.instance;

  Future<String?> uploadImage(File imageFile, String folder) async {
    final String nameFile =
        DateTime.now().millisecondsSinceEpoch.toString() +
        "_" +
        imageFile.path.split('/').last;
    final Reference ref = storage.ref().child(folder).child(nameFile);
    final UploadTask task = ref.putFile(imageFile);
    final TaskSnapshot snapshot = await task;
    return await snapshot.ref.getDownloadURL();
  }
}